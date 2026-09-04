#define MyAppName "FlowBridge"
#define MyAppVersion "0.4.0"
#define MyAppPublisher "FlowBridge contributors"
#define MyAppExeName "FlowBridge.exe"

[Setup]
AppId={{76307A22-A714-48D9-B1BB-F95A65E99653}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
DefaultDirName={localappdata}\Programs\FlowBridge
DefaultGroupName=FlowBridge
DisableProgramGroupPage=yes
PrivilegesRequired=lowest
OutputDir=..\dist
OutputBaseFilename=FlowBridge-Windows-x64-Setup
SetupIconFile=..\assets\FlowBridge.ico
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
LicenseFile=..\LICENSE
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
UninstallDisplayIcon={app}\{#MyAppExeName}
VersionInfoVersion={#MyAppVersion}.0

[Languages]
Name: "turkish"; MessagesFile: "compiler:Languages\Turkish.isl"
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "Masaüstü kısayolu oluştur"; GroupDescription: "Ek görevler:"; Flags: unchecked

[Files]
Source: "..\dist\windows-x64\FlowBridge.exe"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\apps\windows\README.md"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\LICENSE"; DestDir: "{app}"; Flags: ignoreversion

[Icons]
Name: "{group}\FlowBridge"; Filename: "{app}\{#MyAppExeName}"
Name: "{autodesktop}\FlowBridge"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "FlowBridge'i başlat"; Flags: nowait postinstall skipifsilent
