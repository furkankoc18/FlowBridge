# Release guide

## First GitHub publication

The local repository uses the `main` branch. Create an empty public GitHub repository, then run:

```bash
git add .
git commit -m "Release FlowBridge 0.4.0"
git remote add origin https://github.com/OWNER/FlowBridge.git
git push -u origin main
```

In repository settings, enable GitHub Actions, Dependabot alerts, private vulnerability reporting, and branch protection for `main`. Allow the release workflow's `GITHUB_TOKEN` to write repository contents. Add signing secrets before creating a public release if warning-free installers are required.

## Versioning

Keep `VERSION`, `CHANGELOG.md`, the macOS plist values in `scripts/build-macos-app.sh`, the Windows project `Version`, the Inno Setup version, and visible UI versions aligned. Tag releases as `vMAJOR.MINOR.PATCH`.

Run all CI checks and the real-hardware matrix in `docs/TESTING.tr.md` before tagging.

After CI and hardware tests pass, trigger the release workflow with:

```bash
git tag v0.4.0
git push origin v0.4.0
```

## Automated artifacts

Pushing a `v*` tag starts `.github/workflows/release.yml` and produces:

- `FlowBridge-macOS.dmg`
- `FlowBridge-Windows-x64-Setup.exe`
- `FlowBridge-Windows-x64.zip`
- SHA-256 checksum files

The workflow creates a draft GitHub Release so a maintainer can review notes and artifacts before publishing.

## macOS signing and notarization

Public builds should use an Apple Developer ID Application certificate and notarization. Configure these GitHub Actions secrets:

- `MACOS_CERTIFICATE_P12`: Base64-encoded Developer ID Application `.p12`
- `MACOS_CERTIFICATE_PASSWORD`
- `MACOS_SIGNING_IDENTITY`: exact certificate common name
- `APPLE_ID`
- `APPLE_TEAM_ID`
- `APPLE_APP_PASSWORD`: app-specific password

Without all signing/notarization values, the workflow creates an ad-hoc-signed community DMG. Users will receive Gatekeeper warnings. Never commit certificates or passwords.

## Windows signing

Authenticode signing requires a trusted code-signing certificate or managed signing service. Configure:

- `WINDOWS_CERTIFICATE_PFX`: Base64-encoded PFX
- `WINDOWS_CERTIFICATE_PASSWORD`

The workflow signs the portable executable before building the installer, then signs the installer. Without these values, artifacts remain unsigned and SmartScreen may warn.

## Manual verification

After the workflow finishes:

1. Download every artifact and verify its checksum.
2. On macOS run `codesign --verify --deep --strict FlowBridge.app` and `spctl --assess --type execute --verbose FlowBridge.app` after copying it from the DMG.
3. On Windows inspect Properties → Digital Signatures when signing is configured.
4. Install on clean Mac and Windows accounts and complete the pairing, both directions, restart, unpair, and failsafe tests.
5. Confirm the release contains no PDB, certificate, local identity, key, or user data.
6. Publish the draft only after the hardware checks pass.
