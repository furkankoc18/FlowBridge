#!/bin/zsh
set -euo pipefail

FLOWBRIDGE_ROOT="${0:A:h:h}"
FLOWBRIDGE_DOTNET_DIR="${FLOWBRIDGE_DOTNET_DIR:-/tmp/flowbridge-dotnet/sdk}"
FLOWBRIDGE_DOTNET="$FLOWBRIDGE_DOTNET_DIR/dotnet"
FLOWBRIDGE_NUGET_DIR="${FLOWBRIDGE_NUGET_DIR:-/tmp/flowbridge-dotnet/packages}"
FLOWBRIDGE_DOTNET_CLI_HOME="${FLOWBRIDGE_DOTNET_CLI_HOME:-/tmp/flowbridge-dotnet/home}"
FLOWBRIDGE_PROJECT="$FLOWBRIDGE_ROOT/apps/windows/FlowBridge.Windows/FlowBridge.Windows.csproj"
FLOWBRIDGE_OUTPUT="$FLOWBRIDGE_ROOT/dist/windows-x64"

if [[ ! -x "$FLOWBRIDGE_DOTNET" ]]; then
    echo "dotnet bulunamadı: $FLOWBRIDGE_DOTNET" >&2
    echo "Windows'ta .NET 8 SDK kurup bu betiği FLOWBRIDGE_DOTNET_DIR ile çalıştırın." >&2
    exit 1
fi

NUGET_PACKAGES="$FLOWBRIDGE_NUGET_DIR" DOTNET_CLI_HOME="$FLOWBRIDGE_DOTNET_CLI_HOME" \
    "$FLOWBRIDGE_DOTNET" publish "$FLOWBRIDGE_PROJECT" \
    --configuration Release \
    --runtime win-x64 \
    --self-contained true \
    --output "$FLOWBRIDGE_OUTPUT" \
    -p:PublishSingleFile=true \
    -p:IncludeNativeLibrariesForSelfExtract=true

cp "$FLOWBRIDGE_ROOT/apps/windows/README.md" "$FLOWBRIDGE_OUTPUT/README.md"
cp "$FLOWBRIDGE_ROOT/LICENSE" "$FLOWBRIDGE_OUTPUT/LICENSE.txt"
COPYFILE_DISABLE=1 zip -j -FS "$FLOWBRIDGE_ROOT/dist/FlowBridge-Windows-x64.zip" \
    "$FLOWBRIDGE_OUTPUT/FlowBridge.exe" \
    "$FLOWBRIDGE_OUTPUT/README.md" \
    "$FLOWBRIDGE_OUTPUT/LICENSE.txt"
(cd "$FLOWBRIDGE_ROOT/dist" && shasum -a 256 "FlowBridge-Windows-x64.zip" \
    > "FlowBridge-Windows-x64.zip.sha256")

echo "$FLOWBRIDGE_OUTPUT/FlowBridge.exe"
echo "$FLOWBRIDGE_ROOT/dist/FlowBridge-Windows-x64.zip"
