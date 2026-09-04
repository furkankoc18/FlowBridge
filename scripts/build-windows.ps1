$ErrorActionPreference = "Stop"

$root = Split-Path -Parent $PSScriptRoot
$project = Join-Path $root "apps/windows/FlowBridge.Windows/FlowBridge.Windows.csproj"
$output = Join-Path $root "dist/windows-x64"
$zip = Join-Path $root "dist/FlowBridge-Windows-x64.zip"

if (Test-Path $output) { Remove-Item $output -Recurse -Force }
New-Item $output -ItemType Directory -Force | Out-Null
dotnet publish $project --configuration Release --runtime win-x64 --self-contained true `
  --output $output -p:PublishSingleFile=true -p:IncludeNativeLibrariesForSelfExtract=true
Copy-Item (Join-Path $root "apps/windows/README.md") (Join-Path $output "README.md")
Copy-Item (Join-Path $root "LICENSE") (Join-Path $output "LICENSE.txt")
if (Test-Path $zip) { Remove-Item $zip -Force }
Compress-Archive -Path (Join-Path $output "FlowBridge.exe"), (Join-Path $output "README.md"), (Join-Path $output "LICENSE.txt") -DestinationPath $zip
(Get-FileHash $zip -Algorithm SHA256).Hash.ToLowerInvariant() + "  FlowBridge-Windows-x64.zip" |
  Set-Content "$zip.sha256" -Encoding ascii
Write-Output $zip
