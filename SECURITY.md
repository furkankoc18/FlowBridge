# Security policy

## Supported versions

Only the newest tagged release receives security fixes. Pre-release and untagged builds are unsupported.

## Reporting a vulnerability

Do not open a public issue for a vulnerability. Use GitHub's **Security → Report a vulnerability** private reporting feature after the repository is published. If private reporting is unavailable, contact the maintainer through a private channel listed in the GitHub profile.

Include the affected version, operating systems, network assumptions, reproduction steps, impact, and any suggested mitigation. Do not include real pairing keys or personal data.

## Security boundaries

FlowBridge `0.4.0` is designed for two user-approved computers on a trusted local network. It does not provide internet remote access. Initial discovery and pairing negotiation are visible to the LAN. The user must compare the displayed code on both devices; approving mismatched codes defeats man-in-the-middle protection.

After pairing:

- Mouse datagrams use AES-256-GCM with destination-bound authenticated data.
- A random per-process session ID plus monotonic sequence rejects replay within a session and permits safe restarts.
- Pair completion and unpair operations require HMAC-SHA-256 proof of the pairing key.
- macOS stores secrets in Keychain; Windows encrypts them with DPAPI for the current user.
- Input is restored locally after 500 ms without authenticated heartbeat acknowledgement.

The mDNS advertisement and periodic hello are intentionally unauthenticated and may be spoofed to create a fake *unpaired* device row. They cannot inject mouse input or perform trusted control operations without the pairing key.
