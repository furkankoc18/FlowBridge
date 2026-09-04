#!/bin/zsh
set -euo pipefail

FLOWBRIDGE_ROOT="${0:A:h:h}"
FLOWBRIDGE_SMOKE_BINARY="/tmp/flowbridge-pairing-smoke"
FLOWBRIDGE_CONTROL_SMOKE_BINARY="/tmp/flowbridge-control-smoke"

swift build --package-path "$FLOWBRIDGE_ROOT/apps/macos"
swiftc \
    "$FLOWBRIDGE_ROOT/apps/macos/Sources/FlowBridgeMac/Models.swift" \
    "$FLOWBRIDGE_ROOT/apps/macos/Sources/FlowBridgeMac/PairingCrypto.swift" \
    "$FLOWBRIDGE_ROOT/apps/macos/Tests/PairingSmoke/main.swift" \
    -o "$FLOWBRIDGE_SMOKE_BINARY"
"$FLOWBRIDGE_SMOKE_BINARY"

# The live counterpart runs in the Windows smoke project. Compile this side on
# every CI run so protocol model changes cannot silently break the harness.
swiftc \
    "$FLOWBRIDGE_ROOT/apps/macos/Sources/FlowBridgeMac/Models.swift" \
    "$FLOWBRIDGE_ROOT/apps/macos/Sources/FlowBridgeMac/PairingCrypto.swift" \
    "$FLOWBRIDGE_ROOT/apps/macos/Sources/FlowBridgeMac/PeerControlService.swift" \
    "$FLOWBRIDGE_ROOT/apps/macos/Tests/ControlSmoke/main.swift" \
    -o "$FLOWBRIDGE_CONTROL_SMOKE_BINARY"
