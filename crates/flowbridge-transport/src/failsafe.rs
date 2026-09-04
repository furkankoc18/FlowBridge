//! Enforces the product's maximum local-control recovery window.

use flowbridge_core::input::{InputAction, InputEvent, InputOwnership, InvalidTransition};
use std::error::Error;
use std::fmt;
use std::time::Duration;

pub const MAX_LOCAL_RECOVERY_TIME: Duration = Duration::from_millis(500);

#[derive(Debug, Clone)]
pub struct InputFailsafe {
    ownership: InputOwnership,
    last_authenticated_activity: Duration,
    timeout: Duration,
    tripped: bool,
}

impl InputFailsafe {
    pub fn new(
        ownership: InputOwnership,
        started_at: Duration,
        timeout: Duration,
    ) -> Result<Self, FailsafeError> {
        if timeout.is_zero() || timeout > MAX_LOCAL_RECOVERY_TIME {
            return Err(FailsafeError::InvalidTimeout(timeout));
        }
        Ok(Self {
            ownership,
            last_authenticated_activity: started_at,
            timeout,
            tripped: false,
        })
    }

    pub fn record_authenticated_activity(
        &mut self,
        observed_at: Duration,
    ) -> Result<(), FailsafeError> {
        if observed_at < self.last_authenticated_activity {
            return Err(FailsafeError::ClockMovedBackwards);
        }
        self.last_authenticated_activity = observed_at;
        self.tripped = false;
        Ok(())
    }

    /// Return the action the platform adapter must execute when the link has
    /// been silent for the configured timeout. The action is emitted once.
    pub fn poll(&mut self, now: Duration) -> Result<Option<InputAction>, FailsafeError> {
        let elapsed = now
            .checked_sub(self.last_authenticated_activity)
            .ok_or(FailsafeError::ClockMovedBackwards)?;
        if self.tripped || elapsed < self.timeout {
            return Ok(None);
        }

        let (ownership, action) = self
            .ownership
            .transition(InputEvent::ConnectionLost)
            .map_err(FailsafeError::Ownership)?;
        self.ownership = ownership;
        self.tripped = true;
        Ok(Some(action))
    }

    #[must_use]
    pub const fn ownership(&self) -> InputOwnership {
        self.ownership
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum FailsafeError {
    InvalidTimeout(Duration),
    ClockMovedBackwards,
    Ownership(InvalidTransition),
}

impl fmt::Display for FailsafeError {
    fn fmt(&self, formatter: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(formatter, "input failsafe error: {self:?}")
    }
}

impl Error for FailsafeError {}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn rejects_a_recovery_window_over_500_milliseconds() {
        assert_eq!(
            InputFailsafe::new(
                InputOwnership::Remote,
                Duration::ZERO,
                Duration::from_millis(501),
            )
            .unwrap_err(),
            FailsafeError::InvalidTimeout(Duration::from_millis(501))
        );
    }

    #[test]
    fn restores_local_control_at_exactly_the_deadline() {
        let mut failsafe = InputFailsafe::new(
            InputOwnership::Remote,
            Duration::from_millis(100),
            MAX_LOCAL_RECOVERY_TIME,
        )
        .unwrap();

        assert_eq!(failsafe.poll(Duration::from_millis(599)).unwrap(), None);
        assert_eq!(
            failsafe.poll(Duration::from_millis(600)).unwrap(),
            Some(InputAction::RestoreLocalControl)
        );
        assert_eq!(failsafe.ownership(), InputOwnership::Local);
        assert_eq!(failsafe.poll(Duration::from_millis(700)).unwrap(), None);
    }

    #[test]
    fn authenticated_activity_moves_the_deadline() {
        let mut failsafe = InputFailsafe::new(
            InputOwnership::Remote,
            Duration::ZERO,
            Duration::from_millis(250),
        )
        .unwrap();
        failsafe
            .record_authenticated_activity(Duration::from_millis(200))
            .unwrap();

        assert_eq!(failsafe.poll(Duration::from_millis(449)).unwrap(), None);
        assert_eq!(
            failsafe.poll(Duration::from_millis(450)).unwrap(),
            Some(InputAction::RestoreLocalControl)
        );
    }
}
