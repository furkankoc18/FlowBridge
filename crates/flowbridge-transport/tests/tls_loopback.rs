use flowbridge_core::input::{InputAction, InputOwnership};
use flowbridge_protocol::{Frame, InputMessage};
use flowbridge_transport::failsafe::{InputFailsafe, MAX_LOCAL_RECOVERY_TIME};
use flowbridge_transport::frame::{read_frame, write_frame};
use flowbridge_transport::tls;
use rcgen::{CertificateParams, DistinguishedName, DnType};
use rustls::pki_types::{CertificateDer, PrivateKeyDer, PrivatePkcs8KeyDer};
use rustls::server::WebPkiClientVerifier;
use rustls::{ClientConfig, RootCertStore, ServerConfig, SupportedProtocolVersion};
use std::error::Error;
use std::net::TcpListener;
use std::sync::Arc;
use std::time::Duration;

fn identity(
    common_name: &str,
) -> Result<(CertificateDer<'static>, PrivateKeyDer<'static>), Box<dyn Error>> {
    let mut params = CertificateParams::new(vec!["localhost".to_owned()]);
    let mut distinguished_name = DistinguishedName::new();
    distinguished_name.push(DnType::CommonName, common_name);
    params.distinguished_name = distinguished_name;
    let certificate = rcgen::Certificate::from_params(params)?;
    Ok((
        CertificateDer::from(certificate.serialize_der()?),
        PrivatePkcs8KeyDer::from(certificate.serialize_private_key_der()).into(),
    ))
}

struct TestTlsConfigs {
    server: Arc<ServerConfig>,
    authenticated_client: Arc<ClientConfig>,
    unauthenticated_client: Arc<ClientConfig>,
}

fn tls_configs() -> Result<TestTlsConfigs, Box<dyn Error>> {
    static TLS_13_ONLY: [&SupportedProtocolVersion; 1] = [&rustls::version::TLS13];

    let (server_certificate, server_key) = identity("FlowBridge test server")?;
    let (client_certificate, client_key) = identity("FlowBridge test client")?;

    let mut client_roots = RootCertStore::empty();
    client_roots.add(server_certificate.clone())?;
    let client =
        ClientConfig::builder_with_provider(Arc::new(rustls::crypto::ring::default_provider()))
            .with_protocol_versions(&TLS_13_ONLY)?
            .with_root_certificates(client_roots)
            .with_client_auth_cert(vec![client_certificate.clone()], client_key.clone_key())?;

    let mut unauthenticated_client_roots = RootCertStore::empty();
    unauthenticated_client_roots.add(server_certificate.clone())?;
    let unauthenticated_client =
        ClientConfig::builder_with_provider(Arc::new(rustls::crypto::ring::default_provider()))
            .with_protocol_versions(&TLS_13_ONLY)?
            .with_root_certificates(unauthenticated_client_roots)
            .with_no_client_auth();

    let mut client_identity_roots = RootCertStore::empty();
    client_identity_roots.add(client_certificate)?;
    let client_verifier = WebPkiClientVerifier::builder(Arc::new(client_identity_roots)).build()?;
    let server =
        ServerConfig::builder_with_provider(Arc::new(rustls::crypto::ring::default_provider()))
            .with_protocol_versions(&TLS_13_ONLY)?
            .with_client_cert_verifier(client_verifier)
            .with_single_cert(vec![server_certificate], server_key)?;

    Ok(TestTlsConfigs {
        server: Arc::new(server),
        authenticated_client: Arc::new(client),
        unauthenticated_client: Arc::new(unauthenticated_client),
    })
}

#[test]
fn mutual_tls_loopback_carries_heartbeat_and_trips_failsafe() -> Result<(), Box<dyn Error>> {
    let configs = tls_configs()?;
    let server_config = configs.server;
    let client_config = configs.authenticated_client;
    let listener = TcpListener::bind("127.0.0.1:0")?;
    let address = listener.local_addr()?;

    let server = std::thread::spawn(move || -> Result<InputOwnership, String> {
        let (socket, _) = listener.accept().map_err(|error| error.to_string())?;
        let mut stream = tls::accept(socket, server_config).map_err(|error| error.to_string())?;
        let heartbeat = read_frame(&mut stream).map_err(|error| error.to_string())?;
        if heartbeat.message
            != (InputMessage::Heartbeat {
                monotonic_millis: 100,
            })
        {
            return Err(format!("unexpected message: {:?}", heartbeat.message));
        }

        let mut failsafe = InputFailsafe::new(
            InputOwnership::Remote,
            Duration::from_millis(heartbeat.message.monotonic_millis().unwrap_or_default()),
            MAX_LOCAL_RECOVERY_TIME,
        )
        .map_err(|error| error.to_string())?;
        if failsafe
            .poll(Duration::from_millis(600))
            .map_err(|error| error.to_string())?
            != Some(InputAction::RestoreLocalControl)
        {
            return Err("failsafe did not restore local control".to_owned());
        }

        write_frame(
            &mut stream,
            &Frame {
                sequence: 2,
                message: InputMessage::ReleaseControl,
            },
        )
        .map_err(|error| error.to_string())?;
        Ok(failsafe.ownership())
    });

    let mut stream = tls::connect(address, "localhost", client_config)?;
    write_frame(
        &mut stream,
        &Frame {
            sequence: 1,
            message: InputMessage::Heartbeat {
                monotonic_millis: 100,
            },
        },
    )?;
    let response = read_frame(&mut stream)?;
    assert_eq!(response.message, InputMessage::ReleaseControl);
    assert_eq!(
        server.join().map_err(|_| "server thread panicked")??,
        InputOwnership::Local
    );
    Ok(())
}

#[test]
fn server_rejects_a_client_without_a_certificate() -> Result<(), Box<dyn Error>> {
    let configs = tls_configs()?;
    let server_config = configs.server;
    let unauthenticated_client_config = configs.unauthenticated_client;
    let listener = TcpListener::bind("127.0.0.1:0")?;
    let address = listener.local_addr()?;

    let server = std::thread::spawn(move || -> Result<bool, String> {
        let (socket, _) = listener.accept().map_err(|error| error.to_string())?;
        let mut stream = tls::accept(socket, server_config).map_err(|error| error.to_string())?;
        Ok(read_frame(&mut stream).is_err())
    });

    let mut stream = tls::connect(address, "localhost", unauthenticated_client_config)?;
    let frame = Frame {
        sequence: 1,
        message: InputMessage::Heartbeat {
            monotonic_millis: 100,
        },
    };
    let _ = write_frame(&mut stream, &frame);

    assert!(server.join().map_err(|_| "server thread panicked")??);
    Ok(())
}

trait HeartbeatTimestamp {
    fn monotonic_millis(&self) -> Option<u64>;
}

impl HeartbeatTimestamp for InputMessage {
    fn monotonic_millis(&self) -> Option<u64> {
        match self {
            Self::Heartbeat { monotonic_millis } => Some(*monotonic_millis),
            _ => None,
        }
    }
}
