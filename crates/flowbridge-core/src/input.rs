//! Safety-critical ownership state machine for local and remote input.

use crate::screen::Edge;
use std::error::Error;
use std::fmt;

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum InputOwnership {
    Local,
    EdgePending { edge: Edge },
    Remote,
    Returning,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum InputEvent {
    EdgeReached(Edge),
    EdgeLeft,
    EdgeDelayElapsed,
    RemoteReturnRequested,
    ReturnConfirmed,
    ConnectionLost,
    EmergencyShortcut,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum InputAction {
    None,
    StartEdgeDelay,
    AcquireRemoteControl,
    RequestRemoteRelease,
    RestoreLocalControl,
}

impl InputOwnership {
    /// Apply an event. Safety events are accepted in every state and always
    /// restore local control, making the failure behavior explicit and testable.
    pub fn transition(self, event: InputEvent) -> Result<(Self, InputAction), InvalidTransition> {
        use InputAction::{
            AcquireRemoteControl, None, RequestRemoteRelease, RestoreLocalControl, StartEdgeDelay,
        };
        use InputEvent::{
            ConnectionLost, EdgeDelayElapsed, EdgeLeft, EdgeReached, EmergencyShortcut,
            RemoteReturnRequested, ReturnConfirmed,
        };
        use InputOwnership::{EdgePending, Local, Remote, Returning};

        if matches!(event, ConnectionLost | EmergencyShortcut) {
            return Ok((Local, RestoreLocalControl));
        }

        let result = match (self, event) {
            (Local, EdgeReached(edge)) => (EdgePending { edge }, StartEdgeDelay),
            (EdgePending { .. }, EdgeLeft) => (Local, None),
            (EdgePending { .. }, EdgeDelayElapsed) => (Remote, AcquireRemoteControl),
            (Remote, RemoteReturnRequested) => (Returning, RequestRemoteRelease),
            (Returning, ReturnConfirmed) => (Local, RestoreLocalControl),
            _ => return Err(InvalidTransition { state: self, event }),
        };
        Ok(result)
    }

    #[must_use]
    pub const fn routes_input_locally(self) -> bool {
        matches!(
            self,
            Self::Local | Self::EdgePending { .. } | Self::Returning
        )
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct InvalidTransition {
    pub state: InputOwnership,
    pub event: InputEvent,
}

impl fmt::Display for InvalidTransition {
    fn fmt(&self, formatter: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(
            formatter,
            "event {:?} is invalid in {:?}",
            self.event, self.state
        )
    }
}

impl Error for InvalidTransition {}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn edge_delay_can_be_cancelled_without_losing_local_input() {
        let (state, _) = InputOwnership::Local
            .transition(InputEvent::EdgeReached(Edge::Right))
            .unwrap();
        assert!(state.routes_input_locally());
        let (state, _) = state.transition(InputEvent::EdgeLeft).unwrap();
        assert_eq!(state, InputOwnership::Local);
    }

    #[test]
    fn elapsed_edge_delay_transfers_control() {
        let (state, _) = InputOwnership::Local
            .transition(InputEvent::EdgeReached(Edge::Right))
            .unwrap();
        let (state, action) = state.transition(InputEvent::EdgeDelayElapsed).unwrap();
        assert_eq!(state, InputOwnership::Remote);
        assert_eq!(action, InputAction::AcquireRemoteControl);
        assert!(!state.routes_input_locally());
    }

    #[test]
    fn connection_loss_always_restores_local_control() {
        for state in [
            InputOwnership::Local,
            InputOwnership::EdgePending { edge: Edge::Left },
            InputOwnership::Remote,
            InputOwnership::Returning,
        ] {
            assert_eq!(
                state.transition(InputEvent::ConnectionLost),
                Ok((InputOwnership::Local, InputAction::RestoreLocalControl))
            );
        }
    }

    #[test]
    fn emergency_shortcut_always_restores_local_control() {
        for state in [
            InputOwnership::Local,
            InputOwnership::EdgePending { edge: Edge::Right },
            InputOwnership::Remote,
            InputOwnership::Returning,
        ] {
            assert_eq!(
                state.transition(InputEvent::EmergencyShortcut),
                Ok((InputOwnership::Local, InputAction::RestoreLocalControl))
            );
        }
    }
}
