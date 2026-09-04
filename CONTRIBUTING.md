# Contributing to FlowBridge

Thank you for helping improve FlowBridge.

## Before opening a change

- Use an issue for behavior changes, protocol changes, and new features.
- Keep pull requests focused and describe the user-visible result.
- Do not include secrets, signing certificates, device identities, pairing keys, or generated build output.
- Preserve wire compatibility unless the change explicitly increments the protocol version.

## Development checks

Run the checks for every area you touched:

```bash
cargo fmt --all --check
cargo clippy --workspace --all-targets -- -D warnings
cargo test --workspace
./scripts/test-macos-app.sh
```

Windows PowerShell:

```powershell
dotnet format .\apps\windows\FlowBridge.Windows\FlowBridge.Windows.csproj --verify-no-changes
dotnet build .\apps\windows\FlowBridge.Windows\FlowBridge.Windows.csproj -c Release
dotnet run --project .\apps\windows\FlowBridge.Windows.CoreTests\FlowBridge.Windows.CoreTests.csproj -c Release
```

Input-hook changes must also be tested on real hardware. Record the tested OS versions, display scaling, mouse type, source/target direction, return behavior, and `Esc` recovery in the pull request.

## Coding expectations

- Treat all LAN input as hostile until its identity, destination, size, authentication tag, and replay sequence have been validated.
- A lost connection must never leave a mouse button held or local control suppressed.
- Never log pairing keys, clipboard contents, input events, file contents, or stable device identifiers.
- Keep platform APIs in the native app layers and deterministic policy/state logic independently testable.
- Update `CHANGELOG.md`, protocol documentation, and both platform implementations together for wire changes.

By contributing, you agree that your contribution is licensed under the repository's MIT License.
