; The Windows installer, built by Inno Setup from the release build:
;   iscc /DAppVersion=2.5.0 packaging\windows\nazzil.iss   (run in flutter\)
; Paths below are relative to this file. The AppId must never change, or a new
; version installs beside the old one instead of over it.

#ifndef AppVersion
  #error Pass the version: iscc /DAppVersion=x.y.z
#endif
#define Bundle "..\..\build\windows\x64\runner\Release"

[Setup]
AppId={{8711E3AC-C989-4965-B404-A022BA44B789}
AppName=Nazzil
AppVersion={#AppVersion}
AppVerName=Nazzil {#AppVersion}
AppPublisher=Nazzil
DefaultDirName={autopf}\Nazzil
DisableProgramGroupPage=yes
PrivilegesRequiredOverridesAllowed=dialog
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
SetupIconFile=..\..\windows\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\nazzil.exe
OutputDir=..\..\build\dist
OutputBaseFilename=Nazzil-{#AppVersion}-windows-x64-setup
Compression=lzma2
SolidCompression=yes
WizardStyle=modern

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"
#if FileExists(AddBackslash(CompilerPath) + "Languages\Arabic.isl")
Name: "arabic"; MessagesFile: "compiler:Languages\Arabic.isl"
#endif

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
Source: "{#Bundle}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{autoprograms}\Nazzil"; Filename: "{app}\nazzil.exe"
Name: "{autodesktop}\Nazzil"; Filename: "{app}\nazzil.exe"; Tasks: desktopicon

[Run]
Filename: "{app}\nazzil.exe"; Description: "{cm:LaunchProgram,Nazzil}"; Flags: nowait postinstall skipifsilent
