//! Length-delimited reads and writes for protocol frames.

use flowbridge_protocol::{
    payload_len_from_header, Frame, ProtocolError, FRAME_HEADER_LEN, MAX_FRAME_LEN,
};
use std::error::Error;
use std::fmt;
use std::io::{self, Read, Write};

pub fn read_frame(reader: &mut impl Read) -> Result<Frame, FrameIoError> {
    let mut header = [0_u8; FRAME_HEADER_LEN];
    reader.read_exact(&mut header)?;
    let payload_len = payload_len_from_header(&header)?;

    let mut encoded = Vec::with_capacity(FRAME_HEADER_LEN + payload_len);
    encoded.extend_from_slice(&header);
    encoded.resize(FRAME_HEADER_LEN + payload_len, 0);
    reader.read_exact(&mut encoded[FRAME_HEADER_LEN..])?;
    debug_assert!(encoded.len() <= MAX_FRAME_LEN);

    Frame::decode(&encoded).map_err(FrameIoError::Protocol)
}

pub fn write_frame(writer: &mut impl Write, frame: &Frame) -> Result<(), FrameIoError> {
    writer.write_all(&frame.encode())?;
    writer.flush()?;
    Ok(())
}

#[derive(Debug)]
pub enum FrameIoError {
    Io(io::Error),
    Protocol(ProtocolError),
}

impl fmt::Display for FrameIoError {
    fn fmt(&self, formatter: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::Io(error) => write!(formatter, "frame I/O failed: {error}"),
            Self::Protocol(error) => write!(formatter, "invalid frame: {error}"),
        }
    }
}

impl Error for FrameIoError {
    fn source(&self) -> Option<&(dyn Error + 'static)> {
        match self {
            Self::Io(error) => Some(error),
            Self::Protocol(error) => Some(error),
        }
    }
}

impl From<io::Error> for FrameIoError {
    fn from(error: io::Error) -> Self {
        Self::Io(error)
    }
}

impl From<ProtocolError> for FrameIoError {
    fn from(error: ProtocolError) -> Self {
        Self::Protocol(error)
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use flowbridge_protocol::InputMessage;
    use std::io::Cursor;

    #[test]
    fn reads_two_adjacent_frames_without_consuming_the_next_one() {
        let first = Frame {
            sequence: 1,
            message: InputMessage::Heartbeat {
                monotonic_millis: 10,
            },
        };
        let second = Frame {
            sequence: 2,
            message: InputMessage::ReleaseControl,
        };
        let mut bytes = first.encode();
        bytes.extend_from_slice(&second.encode());
        let mut cursor = Cursor::new(bytes);

        assert_eq!(read_frame(&mut cursor).unwrap(), first);
        assert_eq!(read_frame(&mut cursor).unwrap(), second);
    }
}
