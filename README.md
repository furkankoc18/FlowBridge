# FlowBridge

FlowBridge is an open-source, local-network mouse sharing app for macOS and Windows. Pair two computers, move the pointer through the configured screen edge, and keep using the same physical mouse on the other machine.

The current `0.4.0` release supports macOS ↔ Windows, macOS ↔ macOS, and Windows ↔ Windows. It transfers pointer movement, left/right/middle clicks, and scrolling. Keyboard, clipboard, and file transfer are roadmap items and are deliberately not advertised as working features.

## Highlights

- Automatic device discovery on the same LAN using DNS-SD/mDNS plus a local control channel
- User-confirmed six-digit pairing with ephemeral P-256 ECDH
- AES-256-GCM authenticated mouse packets
- HMAC-authenticated pairing completion and unpair messages
- Per-launch random transport session IDs and replay protection
- Keys stored in macOS Keychain or Windows DPAPI-protected storage
- Bidirectional edge switching with an authenticated return signal
- 500 ms heartbeat failsafe, global `Esc` recovery, and injected-event loop prevention
- Native macOS SwiftUI and Windows WPF interfaces
- Self-contained Windows build and drag-to-Applications macOS DMG

## Install

Download the newest files from the repository's **Releases** page.

### macOS 13 or newer

1. Download `FlowBridge-macOS.dmg`, open it, and drag FlowBridge to Applications.
2. Start FlowBridge.
3. Grant **Accessibility** and **Input Monitoring** in System Settings → Privacy & Security.
4. Quit and reopen FlowBridge after granting both permissions.

An unsigned community build may be blocked by Gatekeeper. Maintainer releases should be Developer ID signed and notarized as described in [the release guide](docs/RELEASE.md). For an unsigned local build, right-click the app and choose **Open** only when you trust the source and checksum.

### Windows 10/11 x64

1. Download and run `FlowBridge-Windows-x64-Setup.exe`. The portable ZIP is also available.
2. In FlowBridge, open **Teşhis** and choose **Özel ağ izni ver**. Approve private-network access.
3. Keep the network profile set to **Private**, not Public.

Unsigned community builds can display a SmartScreen warning. Maintainer releases can be Authenticode-signed by supplying the optional release secrets documented in [the release guide](docs/RELEASE.md).

## Pair and use

1. Put both computers on the same trusted local network and open FlowBridge on both.
2. On either computer, open **Cihazlar** and select **Eşleştir** once.
3. Compare the six-digit code on both screens and approve it on both computers.
4. Move the pointer firmly through the edge described by the app. The other computer uses the complementary edge.
5. To return, push back through the edge where the pointer entered. Press `Esc` on the source computer at any time for emergency recovery.

For Mac ↔ Windows, Mac exits on the right and Windows exits on the left. Same-platform pairs choose complementary left/right edges deterministically, so both directions remain available.

See [the Turkish hands-on test plan](docs/TESTING.tr.md) for a complete validation checklist.

## Build from source

Requirements:

- macOS 13+ and Xcode Command Line Tools for the macOS app
- .NET 8 SDK for the Windows app
- Rust 1.75+ for the platform-neutral core
- Inno Setup 6 on Windows to create the installer

```bash
cargo fmt --all --check
cargo clippy --workspace --all-targets -- -D warnings
cargo test --workspace
./scripts/test-macos-app.sh
./scripts/build-macos-app.sh
./scripts/build-macos-dmg.sh
```

On Windows PowerShell:

```powershell
dotnet run --project .\apps\windows\FlowBridge.Windows.CoreTests\FlowBridge.Windows.CoreTests.csproj -c Release
.\scripts\build-windows.ps1
& "${env:ProgramFiles(x86)}\Inno Setup 6\ISCC.exe" .\installer\FlowBridge.iss
```

The Unix cross-publish helper `./scripts/build-windows-app.sh` can produce the portable Windows x64 ZIP when a compatible .NET SDK is available.

## Repository map

- `apps/macos`: native SwiftUI application
- `apps/windows`: native WPF application and smoke tests
- `crates`: protocol, state machine, screen geometry, TLS, and failsafe libraries
- `scripts`: deterministic local packaging helpers
- `.github/workflows`: CI and tag-based GitHub Release builds
- `docs`: architecture, testing, and release operations
- `01-...07-*.md`: original Turkish product research and roadmap

## Security model

FlowBridge is intended for a trusted local network. Discovery and the initial pairing request are visible on the LAN; mouse events and trusted control operations are authenticated with the user-confirmed pairing key. No cloud service, account, analytics, or telemetry is used.

Please report vulnerabilities privately according to [SECURITY.md](SECURITY.md). Architecture and protocol boundaries are documented in [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md).

## Status and scope

This is an early public release. It is suitable for testing, not yet a substitute for accessibility-critical input hardware. Multi-monitor layout editing, keyboard forwarding, clipboard sharing, file transfer, automatic updates, and Linux support remain out of scope for `0.4.0`.

## License

FlowBridge is available under the [MIT License](LICENSE).
