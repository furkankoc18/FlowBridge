//! Wire messages shared by the platform applications.
//!
//! The codec is deliberately small and dependency-free for the first technical
//! prototype. Authentication and encryption belong to the transport layer; a
//! decoded frame must never be treated as trusted merely because it is valid.

#![forbid(unsafe_code)]

use std::error::Error;
use std::fmt;

const MAGIC: [u8; 4] = *b"FBP\0";
/// Bytes before the message payload in every frame.
pub const FRAME_HEADER_LEN: usize = 20;

/// The only wire version understood by this crate.
pub const PROTOCOL_VERSION: u16 = 1;

/// Input frames are intentionally small. Bulk clipboard and file data will use
/// separate, explicitly bounded channels.
pub const MAX_PAYLOAD_LEN: usize = 256;

/// Largest accepted input frame, including its header.
pub const MAX_FRAME_LEN: usize = FRAME_HEADER_LEN + MAX_PAYLOAD_LEN;

#[derive(Debug, Clone, Copy, PartialEq)]
pub struct UnitInterval(f32);

impl UnitInterval {
    pub fn new(value: f32) -> Result<Self, ProtocolError> {
        if value.is_finite() && (0.0..=1.0).contains(&value) {
            Ok(Self(value))
        } else {
            Err(ProtocolError::CoordinateOutOfRange(value))
        }
    }

    #[must_use]
    pub const fn get(self) -> f32 {
        self.0
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
#[repr(u8)]
pub enum Button {
    Primary = 0,
    Secondary = 1,
    Middle = 2,
    Back = 3,
    Forward = 4,
}

impl TryFrom<u8> for Button {
    type Error = ProtocolError;

    fn try_from(value: u8) -> Result<Self, Self::Error> {
        match value {
            0 => Ok(Self::Primary),
            1 => Ok(Self::Secondary),
            2 => Ok(Self::Middle),
            3 => Ok(Self::Back),
            4 => Ok(Self::Forward),
            other => Err(ProtocolError::InvalidEnumValue("button", other)),
        }
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
#[repr(u8)]
pub enum KeyState {
    Up = 0,
    Down = 1,
    Repeat = 2,
}

impl TryFrom<u8> for KeyState {
    type Error = ProtocolError;

    fn try_from(value: u8) -> Result<Self, Self::Error> {
        match value {
            0 => Ok(Self::Up),
            1 => Ok(Self::Down),
            2 => Ok(Self::Repeat),
            other => Err(ProtocolError::InvalidEnumValue("key state", other)),
        }
    }
}

#[derive(Debug, Clone, Copy, Default, PartialEq, Eq)]
pub struct Modifiers(u8);

impl Modifiers {
    pub const SHIFT: u8 = 1 << 0;
    pub const CONTROL: u8 = 1 << 1;
    pub const ALT: u8 = 1 << 2;
    pub const META: u8 = 1 << 3;
    const ALLOWED: u8 = Self::SHIFT | Self::CONTROL | Self::ALT | Self::META;

    pub fn new(bits: u8) -> Result<Self, ProtocolError> {
        if bits & !Self::ALLOWED == 0 {
            Ok(Self(bits))
        } else {
            Err(ProtocolError::InvalidModifiers(bits))
        }
    }

    #[must_use]
    pub const fn bits(self) -> u8 {
        self.0
    }

    #[must_use]
    pub const fn contains(self, flag: u8) -> bool {
        self.0 & flag == flag
    }
}

#[derive(Debug, Clone, PartialEq)]
pub enum InputMessage {
    Heartbeat {
        monotonic_millis: u64,
    },
    PointerMove {
        x: UnitInterval,
        y: UnitInterval,
    },
    PointerButton {
        button: Button,
        pressed: bool,
    },
    Scroll {
        horizontal: f32,
        vertical: f32,
    },
    Key {
        physical_code: u16,
        logical: Option<char>,
        state: KeyState,
        modifiers: Modifiers,
    },
    ReleaseControl,
}

#[derive(Debug, Clone, PartialEq)]
pub struct Frame {
    pub sequence: u64,
    pub message: InputMessage,
}

impl Frame {
    /// Encode a complete length-delimited frame.
    #[must_use]
    pub fn encode(&self) -> Vec<u8> {
        let (kind, payload) = encode_message(&self.message);
        let payload_len = u32::try_from(payload.len()).expect("input payload always fits in u32");
        let mut bytes = Vec::with_capacity(FRAME_HEADER_LEN + payload.len());
        bytes.extend_from_slice(&MAGIC);
        bytes.extend_from_slice(&PROTOCOL_VERSION.to_be_bytes());
        bytes.push(kind);
        bytes.push(0); // Reserved flags; non-zero values are rejected.
        bytes.extend_from_slice(&self.sequence.to_be_bytes());
        bytes.extend_from_slice(&payload_len.to_be_bytes());
        bytes.extend_from_slice(&payload);
        bytes
    }

    pub fn decode(bytes: &[u8]) -> Result<Self, ProtocolError> {
        if bytes.len() < FRAME_HEADER_LEN {
            return Err(ProtocolError::Truncated);
        }
        let payload_len = payload_len_from_header(&bytes[..FRAME_HEADER_LEN])?;

        let sequence = u64::from_be_bytes(
            bytes[8..16]
                .try_into()
                .map_err(|_| ProtocolError::Truncated)?,
        );
        if bytes.len() != FRAME_HEADER_LEN + payload_len {
            return Err(ProtocolError::LengthMismatch {
                declared: payload_len,
                actual: bytes.len().saturating_sub(FRAME_HEADER_LEN),
            });
        }

        let message = decode_message(bytes[6], &bytes[FRAME_HEADER_LEN..])?;
        Ok(Self { sequence, message })
    }
}

/// Validate a fixed-size header and return its declared payload length.
///
/// Transport implementations can use this before allocating or reading the
/// payload. The returned value can never exceed [`MAX_PAYLOAD_LEN`].
pub fn payload_len_from_header(header: &[u8]) -> Result<usize, ProtocolError> {
    if header.len() != FRAME_HEADER_LEN {
        return Err(ProtocolError::InvalidHeaderLength(header.len()));
    }
    if header[..4] != MAGIC {
        return Err(ProtocolError::InvalidMagic);
    }

    let version = u16::from_be_bytes([header[4], header[5]]);
    if version != PROTOCOL_VERSION {
        return Err(ProtocolError::UnsupportedVersion(version));
    }
    if header[7] != 0 {
        return Err(ProtocolError::UnsupportedFlags(header[7]));
    }

    let payload_len = u32::from_be_bytes(
        header[16..20]
            .try_into()
            .map_err(|_| ProtocolError::Truncated)?,
    ) as usize;
    if payload_len > MAX_PAYLOAD_LEN {
        return Err(ProtocolError::PayloadTooLarge(payload_len));
    }
    Ok(payload_len)
}

fn encode_message(message: &InputMessage) -> (u8, Vec<u8>) {
    match message {
        InputMessage::Heartbeat { monotonic_millis } => {
            (0, monotonic_millis.to_be_bytes().to_vec())
        }
        InputMessage::PointerMove { x, y } => {
            let mut payload = Vec::with_capacity(8);
            payload.extend_from_slice(&x.get().to_bits().to_be_bytes());
            payload.extend_from_slice(&y.get().to_bits().to_be_bytes());
            (1, payload)
        }
        InputMessage::PointerButton { button, pressed } => {
            (2, vec![*button as u8, u8::from(*pressed)])
        }
        InputMessage::Scroll {
            horizontal,
            vertical,
        } => {
            let mut payload = Vec::with_capacity(8);
            payload.extend_from_slice(&horizontal.to_bits().to_be_bytes());
            payload.extend_from_slice(&vertical.to_bits().to_be_bytes());
            (3, payload)
        }
        InputMessage::Key {
            physical_code,
            logical,
            state,
            modifiers,
        } => {
            let mut payload = Vec::with_capacity(8);
            payload.extend_from_slice(&physical_code.to_be_bytes());
            payload.extend_from_slice(&logical.map_or(u32::MAX, u32::from).to_be_bytes());
            payload.push(*state as u8);
            payload.push(modifiers.bits());
            (4, payload)
        }
        InputMessage::ReleaseControl => (5, Vec::new()),
    }
}

fn decode_message(kind: u8, payload: &[u8]) -> Result<InputMessage, ProtocolError> {
    match kind {
        0 => {
            require_len(payload, 8)?;
            Ok(InputMessage::Heartbeat {
                monotonic_millis: u64::from_be_bytes(
                    payload.try_into().map_err(|_| ProtocolError::Truncated)?,
                ),
            })
        }
        1 => {
            require_len(payload, 8)?;
            let x = f32::from_bits(u32::from_be_bytes(
                payload[..4]
                    .try_into()
                    .map_err(|_| ProtocolError::Truncated)?,
            ));
            let y = f32::from_bits(u32::from_be_bytes(
                payload[4..]
                    .try_into()
                    .map_err(|_| ProtocolError::Truncated)?,
            ));
            Ok(InputMessage::PointerMove {
                x: UnitInterval::new(x)?,
                y: UnitInterval::new(y)?,
            })
        }
        2 => {
            require_len(payload, 2)?;
            let pressed = match payload[1] {
                0 => false,
                1 => true,
                other => return Err(ProtocolError::InvalidBoolean(other)),
            };
            Ok(InputMessage::PointerButton {
                button: Button::try_from(payload[0])?,
                pressed,
            })
        }
        3 => {
            require_len(payload, 8)?;
            let horizontal = decode_finite_f32(&payload[..4])?;
            let vertical = decode_finite_f32(&payload[4..])?;
            Ok(InputMessage::Scroll {
                horizontal,
                vertical,
            })
        }
        4 => {
            require_len(payload, 8)?;
            let physical_code = u16::from_be_bytes([payload[0], payload[1]]);
            let scalar = u32::from_be_bytes(
                payload[2..6]
                    .try_into()
                    .map_err(|_| ProtocolError::Truncated)?,
            );
            let logical = if scalar == u32::MAX {
                None
            } else {
                Some(char::from_u32(scalar).ok_or(ProtocolError::InvalidCharacter(scalar))?)
            };
            Ok(InputMessage::Key {
                physical_code,
                logical,
                state: KeyState::try_from(payload[6])?,
                modifiers: Modifiers::new(payload[7])?,
            })
        }
        5 => {
            require_len(payload, 0)?;
            Ok(InputMessage::ReleaseControl)
        }
        other => Err(ProtocolError::UnknownMessageKind(other)),
    }
}

fn decode_finite_f32(bytes: &[u8]) -> Result<f32, ProtocolError> {
    let value = f32::from_bits(u32::from_be_bytes(
        bytes.try_into().map_err(|_| ProtocolError::Truncated)?,
    ));
    if value.is_finite() {
        Ok(value)
    } else {
        Err(ProtocolError::NonFiniteNumber)
    }
}

fn require_len(payload: &[u8], expected: usize) -> Result<(), ProtocolError> {
    if payload.len() == expected {
        Ok(())
    } else {
        Err(ProtocolError::InvalidPayloadLength {
            expected,
            actual: payload.len(),
        })
    }
}

#[derive(Debug, Clone, PartialEq)]
pub enum ProtocolError {
    Truncated,
    InvalidHeaderLength(usize),
    InvalidMagic,
    UnsupportedVersion(u16),
    UnsupportedFlags(u8),
    PayloadTooLarge(usize),
    LengthMismatch { declared: usize, actual: usize },
    UnknownMessageKind(u8),
    InvalidPayloadLength { expected: usize, actual: usize },
    CoordinateOutOfRange(f32),
    InvalidEnumValue(&'static str, u8),
    InvalidBoolean(u8),
    InvalidModifiers(u8),
    InvalidCharacter(u32),
    NonFiniteNumber,
}

impl fmt::Display for ProtocolError {
    fn fmt(&self, formatter: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(formatter, "{self:?}")
    }
}

impl Error for ProtocolError {}

#[cfg(test)]
mod tests {
    use super::*;

    fn round_trip(message: InputMessage) {
        let frame = Frame {
            sequence: 42,
            message,
        };
        assert_eq!(Frame::decode(&frame.encode()), Ok(frame));
    }

    #[test]
    fn every_message_round_trips() {
        round_trip(InputMessage::Heartbeat {
            monotonic_millis: 12_345,
        });
        round_trip(InputMessage::PointerMove {
            x: UnitInterval::new(0.25).unwrap(),
            y: UnitInterval::new(1.0).unwrap(),
        });
        round_trip(InputMessage::PointerButton {
            button: Button::Back,
            pressed: true,
        });
        round_trip(InputMessage::Scroll {
            horizontal: -1.25,
            vertical: 3.5,
        });
        round_trip(InputMessage::Key {
            physical_code: 44,
            logical: Some('ş'),
            state: KeyState::Down,
            modifiers: Modifiers::new(Modifiers::META | Modifiers::SHIFT).unwrap(),
        });
        round_trip(InputMessage::ReleaseControl);
    }

    #[test]
    fn rejects_declared_oversized_payload_before_reading_it() {
        let mut bytes = Frame {
            sequence: 1,
            message: InputMessage::ReleaseControl,
        }
        .encode();
        bytes[16..20].copy_from_slice(&((MAX_PAYLOAD_LEN + 1) as u32).to_be_bytes());
        assert_eq!(
            Frame::decode(&bytes),
            Err(ProtocolError::PayloadTooLarge(MAX_PAYLOAD_LEN + 1))
        );
    }

    #[test]
    fn rejects_non_finite_pointer_coordinates() {
        let mut bytes = Frame {
            sequence: 1,
            message: InputMessage::PointerMove {
                x: UnitInterval::new(0.5).unwrap(),
                y: UnitInterval::new(0.5).unwrap(),
            },
        }
        .encode();
        bytes[FRAME_HEADER_LEN..FRAME_HEADER_LEN + 4]
            .copy_from_slice(&f32::NAN.to_bits().to_be_bytes());
        assert!(matches!(
            Frame::decode(&bytes),
            Err(ProtocolError::CoordinateOutOfRange(value)) if value.is_nan()
        ));
    }

    #[test]
    fn rejects_trailing_data() {
        let mut bytes = Frame {
            sequence: 1,
            message: InputMessage::ReleaseControl,
        }
        .encode();
        bytes.push(0);
        assert_eq!(
            Frame::decode(&bytes),
            Err(ProtocolError::LengthMismatch {
                declared: 0,
                actual: 1,
            })
        );
    }

    #[test]
    fn validates_header_without_reading_payload() {
        let bytes = Frame {
            sequence: 9,
            message: InputMessage::Heartbeat {
                monotonic_millis: 50,
            },
        }
        .encode();
        assert_eq!(payload_len_from_header(&bytes[..FRAME_HEADER_LEN]), Ok(8));
        assert_eq!(
            payload_len_from_header(&bytes[..FRAME_HEADER_LEN - 1]),
            Err(ProtocolError::InvalidHeaderLength(FRAME_HEADER_LEN - 1))
        );
    }
}
