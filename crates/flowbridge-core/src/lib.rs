//! Platform-neutral FlowBridge state and coordinate logic.

#![forbid(unsafe_code)]

pub mod connection;
pub mod input;
pub mod screen;

pub use flowbridge_protocol as protocol;
