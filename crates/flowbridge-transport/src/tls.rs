//! TLS 1.3-only TCP connection helpers.

use rustls::pki_types::ServerName;
use rustls::{ClientConfig, ClientConnection, ServerConfig, ServerConnection, StreamOwned};
use std::error::Error;
use std::fmt;
use std::net::{SocketAddr, TcpStream};
use std::sync::Arc;

pub type ClientTlsStream = StreamOwned<ClientConnection, TcpStream>;
pub type ServerTlsStream = StreamOwned<ServerConnection, TcpStream>;

pub fn connect(
    address: SocketAddr,
    server_name: &str,
    config: Arc<ClientConfig>,
) -> Result<ClientTlsStream, TlsConnectError> {
    let name = ServerName::try_from(server_name.to_owned())
        .map_err(|_| TlsConnectError::InvalidServerName(server_name.to_owned()))?;
    let connection = ClientConnection::new(config, name)?;
    let socket = TcpStream::connect(address)?;
    socket.set_nodelay(true)?;
    Ok(StreamOwned::new(connection, socket))
}

pub fn accept(
    socket: TcpStream,
    config: Arc<ServerConfig>,
) -> Result<ServerTlsStream, TlsConnectError> {
    socket.set_nodelay(true)?;
    let connection = ServerConnection::new(config)?;
    Ok(StreamOwned::new(connection, socket))
}

#[derive(Debug)]
pub enum TlsConnectError {
    Io(std::io::Error),
    Tls(rustls::Error),
    InvalidServerName(String),
}

impl fmt::Display for TlsConnectError {
    fn fmt(&self, formatter: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::Io(error) => write!(formatter, "TCP setup failed: {error}"),
            Self::Tls(error) => write!(formatter, "TLS setup failed: {error}"),
            Self::InvalidServerName(name) => write!(formatter, "invalid server name: {name}"),
        }
    }
}

impl Error for TlsConnectError {
    fn source(&self) -> Option<&(dyn Error + 'static)> {
        match self {
            Self::Io(error) => Some(error),
            Self::Tls(error) => Some(error),
            Self::InvalidServerName(_) => None,
        }
    }
}

impl From<std::io::Error> for TlsConnectError {
    fn from(error: std::io::Error) -> Self {
        Self::Io(error)
    }
}

impl From<rustls::Error> for TlsConnectError {
    fn from(error: rustls::Error) -> Self {
        Self::Tls(error)
    }
}
