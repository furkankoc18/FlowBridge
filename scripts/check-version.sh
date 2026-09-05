#!/usr/bin/env bash
set -euo pipefail

FLOWBRIDGE_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
FLOWBRIDGE_VERSION=$(<"$FLOWBRIDGE_ROOT/VERSION")

grep -Fq "CFBundleShortVersionString -string \"$FLOWBRIDGE_VERSION\"" "$FLOWBRIDGE_ROOT/scripts/build-macos-app.sh"
grep -Fq "<Version>$FLOWBRIDGE_VERSION</Version>" "$FLOWBRIDGE_ROOT/apps/windows/FlowBridge.Windows/FlowBridge.Windows.csproj"
grep -Fq "#define MyAppVersion \"$FLOWBRIDGE_VERSION\"" "$FLOWBRIDGE_ROOT/installer/FlowBridge.iss"
grep -Fq "FlowBridge Windows · $FLOWBRIDGE_VERSION" "$FLOWBRIDGE_ROOT/apps/windows/FlowBridge.Windows/MainWindow.xaml"
grep -Fq 'current `'$FLOWBRIDGE_VERSION'` release' "$FLOWBRIDGE_ROOT/README.md"

echo "Version metadata is consistent: $FLOWBRIDGE_VERSION"
