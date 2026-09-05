#!/bin/zsh
set -euo pipefail

FLOWBRIDGE_ROOT="${0:A:h:h}"
FLOWBRIDGE_SOURCE="$FLOWBRIDGE_ROOT/dist/FlowBridge.app"
FLOWBRIDGE_USER_NAME=$(id -un)
FLOWBRIDGE_USER_DIR=$(dscl . -read "/Users/$FLOWBRIDGE_USER_NAME" NFSHomeDirectory | awk '{print $2}')
if [[ -z "$FLOWBRIDGE_USER_DIR" || ! -d "$FLOWBRIDGE_USER_DIR" ]]; then
    echo "Kullanıcı ana dizini bulunamadı: $FLOWBRIDGE_USER_NAME" >&2
    exit 1
fi
FLOWBRIDGE_APPLICATIONS="$FLOWBRIDGE_USER_DIR/Applications"
FLOWBRIDGE_DESTINATION="$FLOWBRIDGE_APPLICATIONS/FlowBridge.app"

if [[ ! -d "$FLOWBRIDGE_SOURCE" ]]; then
    echo "Önce ./scripts/build-macos-app.sh çalıştırılmalı." >&2
    exit 1
fi

mkdir -p "$FLOWBRIDGE_APPLICATIONS"
ditto "$FLOWBRIDGE_SOURCE" "$FLOWBRIDGE_DESTINATION"
codesign --verify --deep --strict "$FLOWBRIDGE_DESTINATION"
if [[ "${FLOWBRIDGE_SKIP_OPEN:-0}" != "1" ]]; then
    open "$FLOWBRIDGE_DESTINATION"
fi
echo "$FLOWBRIDGE_DESTINATION"
