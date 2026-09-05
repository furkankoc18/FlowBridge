#!/bin/zsh
set -euo pipefail

FLOWBRIDGE_ROOT="${0:A:h:h}"
FLOWBRIDGE_PACKAGE="$FLOWBRIDGE_ROOT/apps/macos"
FLOWBRIDGE_DIST="$FLOWBRIDGE_ROOT/dist"
FLOWBRIDGE_APP="$FLOWBRIDGE_DIST/FlowBridge.app"
FLOWBRIDGE_CONTENTS="$FLOWBRIDGE_APP/Contents"
FLOWBRIDGE_CODESIGN_IDENTITY="${FLOWBRIDGE_CODESIGN_IDENTITY:--}"
FLOWBRIDGE_SWIFT_ARGS=(--package-path "$FLOWBRIDGE_PACKAGE" --configuration release)

if [[ -n "${FLOWBRIDGE_MACOS_ARCHS:-}" ]]; then
    for FLOWBRIDGE_ARCH in ${(z)FLOWBRIDGE_MACOS_ARCHS}; do
        FLOWBRIDGE_SWIFT_ARGS+=(--arch "$FLOWBRIDGE_ARCH")
    done
fi

swift build "${FLOWBRIDGE_SWIFT_ARGS[@]}"
FLOWBRIDGE_BIN_PATH=$(swift build "${FLOWBRIDGE_SWIFT_ARGS[@]}" --show-bin-path)

rm -rf "$FLOWBRIDGE_APP"
mkdir -p "$FLOWBRIDGE_CONTENTS/MacOS" "$FLOWBRIDGE_CONTENTS/Resources"
cp "$FLOWBRIDGE_BIN_PATH/FlowBridgeMac" "$FLOWBRIDGE_CONTENTS/MacOS/FlowBridge"
cp "$FLOWBRIDGE_ROOT/assets/FlowBridge.icns" "$FLOWBRIDGE_CONTENTS/Resources/FlowBridge.icns"

plutil -create xml1 "$FLOWBRIDGE_CONTENTS/Info.plist"
plutil -insert CFBundleName -string "FlowBridge" "$FLOWBRIDGE_CONTENTS/Info.plist"
plutil -insert CFBundleDisplayName -string "FlowBridge" "$FLOWBRIDGE_CONTENTS/Info.plist"
plutil -insert CFBundleIdentifier -string "com.flowbridge.app" "$FLOWBRIDGE_CONTENTS/Info.plist"
plutil -insert CFBundleExecutable -string "FlowBridge" "$FLOWBRIDGE_CONTENTS/Info.plist"
plutil -insert CFBundlePackageType -string "APPL" "$FLOWBRIDGE_CONTENTS/Info.plist"
plutil -insert CFBundleShortVersionString -string "0.4.0" "$FLOWBRIDGE_CONTENTS/Info.plist"
plutil -insert CFBundleVersion -string "9" "$FLOWBRIDGE_CONTENTS/Info.plist"
plutil -insert CFBundleIconFile -string "FlowBridge" "$FLOWBRIDGE_CONTENTS/Info.plist"
plutil -insert CFBundleIconName -string "FlowBridge" "$FLOWBRIDGE_CONTENTS/Info.plist"
plutil -insert LSMinimumSystemVersion -string "13.0" "$FLOWBRIDGE_CONTENTS/Info.plist"
plutil -insert LSApplicationCategoryType -string "public.app-category.utilities" "$FLOWBRIDGE_CONTENTS/Info.plist"
plutil -insert NSHighResolutionCapable -bool true "$FLOWBRIDGE_CONTENTS/Info.plist"
plutil -insert NSLocalNetworkUsageDescription -string "FlowBridge aynı ağdaki eşleşebileceğiniz cihazları bulur." "$FLOWBRIDGE_CONTENTS/Info.plist"
plutil -insert NSBonjourServices -json '["_flowbridge._tcp"]' "$FLOWBRIDGE_CONTENTS/Info.plist"

if [[ "$FLOWBRIDGE_CODESIGN_IDENTITY" == "-" ]]; then
    plutil -insert FlowBridgeAdHocBuild -bool true "$FLOWBRIDGE_CONTENTS/Info.plist"
    codesign --force --deep --sign - "$FLOWBRIDGE_APP"
else
    plutil -insert FlowBridgeAdHocBuild -bool false "$FLOWBRIDGE_CONTENTS/Info.plist"
    codesign --force --deep --options runtime --timestamp \
        --sign "$FLOWBRIDGE_CODESIGN_IDENTITY" "$FLOWBRIDGE_APP"
fi
codesign --verify --deep --strict "$FLOWBRIDGE_APP"
echo "$FLOWBRIDGE_APP"
