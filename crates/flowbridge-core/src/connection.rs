//! Connection lifecycle without transport-specific side effects.

use std::error::Error;
use std::fmt;

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum ConnectionState {
    Discovered,
    Pairing,
    Trusted,
    Connecting { attempt: u8 },
    Connected,
    Backoff { attempt: u8 },
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum ConnectionEvent {
    PairingStarted,
    PairingApproved,
    PairingRejected,
    ConnectRequested,
    ConnectSucceeded,
    ConnectFailed,
    RetryElapsed,
    Disconnected,
    TrustRemoved,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum ConnectionAction {
    None,
    PersistTrust,
    OpenAuthenticatedTransport,
    ScheduleRetry { attempt: u8 },
    CloseTransport,
    RemovePersistedTrust,
    CloseTransportAndRemoveTrust,
}

impl ConnectionState {
    pub fn transition(
        self,
        event: ConnectionEvent,
    ) -> Result<(Self, ConnectionAction), InvalidTransition> {
        use ConnectionAction::{
            CloseTransportAndRemoveTrust, None, OpenAuthenticatedTransport, PersistTrust,
            RemovePersistedTrust,
        };
        use ConnectionEvent::{
            ConnectFailed, ConnectRequested, ConnectSucceeded, Disconnected, PairingApproved,
            PairingRejected, PairingStarted, RetryElapsed, TrustRemoved,
        };
        use ConnectionState::{Backoff, Connected, Connecting, Discovered, Pairing, Trusted};

        let result = match (self, event) {
            (Discovered, PairingStarted) => (Pairing, None),
            (Pairing, PairingApproved) => (Trusted, PersistTrust),
            (Pairing, PairingRejected) => (Discovered, None),
            (Trusted, ConnectRequested) => (Connecting { attempt: 0 }, OpenAuthenticatedTransport),
            (Connecting { .. }, ConnectSucceeded) => (Connected, None),
            (Connecting { attempt }, ConnectFailed) => {
                let next = attempt.saturating_add(1);
                (
                    Backoff { attempt: next },
                    ConnectionAction::ScheduleRetry { attempt: next },
                )
            }
            (Connected, Disconnected) => (
                Backoff { attempt: 1 },
                ConnectionAction::ScheduleRetry { attempt: 1 },
            ),
            (Backoff { attempt }, RetryElapsed) => {
                (Connecting { attempt }, OpenAuthenticatedTransport)
            }
            (Connected | Connecting { .. } | Backoff { .. }, TrustRemoved) => {
                (Discovered, CloseTransportAndRemoveTrust)
            }
            (Trusted, TrustRemoved) => (Discovered, RemovePersistedTrust),
            _ => return Err(InvalidTransition { state: self, event }),
        };
        Ok(result)
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct InvalidTransition {
    pub state: ConnectionState,
    pub event: ConnectionEvent,
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
    fn happy_path_requires_pairing_before_connection() {
        let (state, _) = ConnectionState::Discovered
            .transition(ConnectionEvent::PairingStarted)
            .unwrap();
        let (state, action) = state.transition(ConnectionEvent::PairingApproved).unwrap();
        assert_eq!(state, ConnectionState::Trusted);
        assert_eq!(action, ConnectionAction::PersistTrust);

        let (state, action) = state.transition(ConnectionEvent::ConnectRequested).unwrap();
        assert_eq!(state, ConnectionState::Connecting { attempt: 0 });
        assert_eq!(action, ConnectionAction::OpenAuthenticatedTransport);

        let (state, _) = state.transition(ConnectionEvent::ConnectSucceeded).unwrap();
        assert_eq!(state, ConnectionState::Connected);
    }

    #[test]
    fn untrusted_device_cannot_connect() {
        assert_eq!(
            ConnectionState::Discovered.transition(ConnectionEvent::ConnectRequested),
            Err(InvalidTransition {
                state: ConnectionState::Discovered,
                event: ConnectionEvent::ConnectRequested,
            })
        );
    }

    #[test]
    fn disconnect_enters_bounded_backoff_counter() {
        let (state, action) = ConnectionState::Connected
            .transition(ConnectionEvent::Disconnected)
            .unwrap();
        assert_eq!(state, ConnectionState::Backoff { attempt: 1 });
        assert_eq!(action, ConnectionAction::ScheduleRetry { attempt: 1 });

        let (state, _) = state.transition(ConnectionEvent::RetryElapsed).unwrap();
        assert_eq!(state, ConnectionState::Connecting { attempt: 1 });

        let (state, _) = state.transition(ConnectionEvent::ConnectFailed).unwrap();
        assert_eq!(state, ConnectionState::Backoff { attempt: 2 });
    }

    #[test]
    fn removing_trust_closes_an_active_transport_and_forgets_the_device() {
        let (state, action) = ConnectionState::Connected
            .transition(ConnectionEvent::TrustRemoved)
            .unwrap();
        assert_eq!(state, ConnectionState::Discovered);
        assert_eq!(action, ConnectionAction::CloseTransportAndRemoveTrust);

        let (state, action) = ConnectionState::Trusted
            .transition(ConnectionEvent::TrustRemoved)
            .unwrap();
        assert_eq!(state, ConnectionState::Discovered);
        assert_eq!(action, ConnectionAction::RemovePersistedTrust);
    }
}
