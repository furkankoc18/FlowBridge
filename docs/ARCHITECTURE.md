# Architecture and protocol

## Runtime components

Each computer runs the same peer architecture:

1. DNS-SD/mDNS advertises `_flowbridge._tcp` and discovers nearby instances.
2. UDP `45874` carries bounded control envelopes: hello, pairing request/challenge/acceptance, and unpair.
3. Native input capture detects an exit edge and suppresses physical source events while remote control is active.
4. UDP `45875` carries bounded AES-GCM mouse envelopes, using unicast after the peer address is known and authenticated multicast fallback during startup.
5. The target injects authenticated mouse events through CoreGraphics or Windows `SendInput`.
6. Heartbeat acknowledgements and authenticated return messages restore source ownership.

The Rust crates hold protocol codecs, connection/input state machines, geometry, framed I/O, TLS 1.3 support for future reliable bulk channels, and failsafe tests. The current native mouse path uses the lower-latency authenticated UDP transport; it does not claim to use the Rust TLS layer.

## Pairing

The initiator sends an ephemeral P-256 public key. The target answers with another ephemeral public key. Both derive the same 32-byte key from raw ECDH material and an ordered device-ID transcript. The six-digit UI code is derived from that key. Both users must approve the same code.

The final `pairAccepted` message includes HMAC-SHA-256 over message type, sender, recipient, and request ID. A session is persisted only after local approval and a valid remote proof. `unpair` uses the same authenticated-control construction.

## Mouse envelope v2

The JSON envelope contains:

- protocol version `2`
- 128-bit hexadecimal sender and recipient IDs
- random 128-bit hexadecimal process session ID
- monotonic unsigned 64-bit session sequence
- Base64 encoded AES-GCM combined nonce, ciphertext, and tag

Authenticated additional data is:

`FlowBridge/mouse/v2|fromId|toId|sessionId|sequence`

The decrypted payload contains `kind`, relative deltas, button, scroll amount, normalized entry height, and entry edge. Packets are capped at 2048 bytes and ignored unless the peer key exists, the destination matches, authentication succeeds, and the sequence is fresh.

## Direction policy

Mac → Windows keeps the established right-edge exit. Windows → Mac uses the left edge. Same-platform peers compare stable device IDs: the lower ID exits right and the higher ID exits left. This produces complementary directions without a central coordinator. The receiver is told the exact entry edge so return detection works uniformly.

## Safety properties

- Injected events carry an OS marker/flag and are never captured again.
- The source hides and decouples its pointer only during an active remote session.
- Every source session sends heartbeats every 100 ms; the target returns authenticated acknowledgements.
- No acknowledgement for 500 ms restores local pointer ownership.
- Target-side button state is released after 500 ms of authenticated silence and on leave/return/stop.
- Global `Esc` restores local ownership on the source.
- Disabling sharing stops source capture and target injection.

## Current limits

Only the primary display is used. Exactly one trusted target is selected automatically. Keyboard, clipboard, file transfer, visual multi-monitor layout, auto-update, and internet traversal are not implemented in `0.4.0`.
