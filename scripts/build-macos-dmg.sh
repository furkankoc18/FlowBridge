#!/bin/zsh
set -euo pipefail

FLOWBRIDGE_ROOT="${0:A:h:h}"
FLOWBRIDGE_DIST="$FLOWBRIDGE_ROOT/dist"
FLOWBRIDGE_APP="$FLOWBRIDGE_DIST/FlowBridge.app"
FLOWBRIDGE_DMG="$FLOWBRIDGE_DIST/FlowBridge-macOS.dmg"
FLOWBRIDGE_STAGE="$FLOWBRIDGE_DIST/dmg-stage"

if [[ ! -d "$FLOWBRIDGE_APP" ]]; then
    "$FLOWBRIDGE_ROOT/scripts/build-macos-app.sh"
fi

rm -rf "$FLOWBRIDGE_STAGE"
rm -f "$FLOWBRIDGE_DMG"
mkdir -p "$FLOWBRIDGE_STAGE"
ditto "$FLOWBRIDGE_APP" "$FLOWBRIDGE_STAGE/FlowBridge.app"
cp "$FLOWBRIDGE_ROOT/LICENSE" "$FLOWBRIDGE_STAGE/LICENSE.txt"
ln -s /Applications "$FLOWBRIDGE_STAGE/Applications"
hdiutil create -volname "FlowBridge" -srcfolder "$FLOWBRIDGE_STAGE" \
    -ov -format UDZO "$FLOWBRIDGE_DMG"
rm -rf "$FLOWBRIDGE_STAGE"
(cd "$FLOWBRIDGE_DIST" && shasum -a 256 "FlowBridge-macOS.dmg" > "FlowBridge-macOS.dmg.sha256")
echo "$FLOWBRIDGE_DMG"
