#define AppName "switcherit"
#define AppExeName "switcherit.exe"
#define AppVersion GetEnv("SWITCHERIT_VERSION")
#if AppVersion == ""
  #define AppVersion "dev"
#endif
#define AppVersionQuad GetEnv("SWITCHERIT_VERSION_QUAD")
#if AppVersionQuad == ""
  #define AppVersionQuad "0.0.0.0"
#endif

[Setup]
AppId={{8F4662A1-053B-48EF-99BC-49AAED95D6B7}
AppName={#AppName}
AppVersion={#AppVersion}
VersionInfoVersion={#AppVersionQuad}
VersionInfoTextVersion={#AppVersion}
AppPublisher=switcherit
DefaultDirName={autopf}\{#AppName}
DefaultGroupName={#AppName}
DisableProgramGroupPage=yes
OutputBaseFilename=switcherit-{#AppVersion}-Setup
OutputDir=..\dist
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
SetupIconFile=..\assets\switcherit-tray.ico
UninstallDisplayIcon={app}\{#AppExeName}

[Files]
Source: "..\build\{#AppExeName}"; DestDir: "{app}"; Flags: ignoreversion

[Icons]
Name: "{group}\{#AppName}"; Filename: "{app}\{#AppExeName}"
Name: "{autodesktop}\{#AppName}"; Filename: "{app}\{#AppExeName}"; Tasks: desktopicon

[Tasks]
Name: "desktopicon"; Description: "Create a desktop shortcut"; GroupDescription: "Additional shortcuts:"; Flags: unchecked

[Run]
Filename: "{app}\{#AppExeName}"; Description: "Launch {#AppName}"; Flags: nowait postinstall skipifsilent
