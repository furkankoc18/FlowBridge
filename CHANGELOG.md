# Changelog

All notable changes to FlowBridge are documented here. The project follows semantic versioning while the public API and wire protocol are still experimental.

## 0.4.0 - 2026-09-05

- Added bidirectional mouse sharing for Mac ↔ Windows, Mac ↔ Mac, and Windows ↔ Windows.
- Added direction-aware entry/return edges and authenticated return messages.
- Added Windows global `Esc` recovery and increased Windows-source pointer responsiveness.
- Added bidirectional heartbeat acknowledgements with a 500 ms local-control failsafe.
- Added per-launch random transport session IDs to preserve replay protection across restarts.
- Added HMAC authentication to pairing completion and unpair control messages.
- Added macOS Dock and Windows taskbar/application icons.
- Added macOS DMG, Windows portable ZIP, and Inno Setup packaging.
- Added CI, tag release automation, checksums, open-source policy files, and release documentation.
- Changed the macOS bundle and Keychain service from the development identifier to the stable public identifier; `0.3.x` macOS users must pair once again after upgrading.
- Replaced the abandoned .NET Standard mDNS dependency with its maintained .NET 8 fork to remove vulnerable legacy transitive packages.
- Updated the dormant Rust TLS helper from rustls 0.21 to rustls 0.23.43 and rustls-webpki 0.103.15.
