; Inno Setup script — Jahan Bit (جهان بیت)
; Build Windows release first:
;   flutter build windows --release
; Then compile this script with Inno Setup.

[Setup]
AppId={{9D14829D-5B3D-4208-BFCA-0A1A2B95C7F1}
AppName=Jahan Bit
AppVersion=1.0.0
AppPublisher=Jahan Bit
AppPublisherURL=https://github.com
AppSupportURL=https://github.com
AppCopyright=Copyright (C) 2026 Jahan Bit
DefaultDirName={autopf}\Jahan Bit
DefaultGroupName=Jahan Bit
DisableProgramGroupPage=yes
OutputDir=dist\installer
OutputBaseFilename=Jahan_Bit-Setup
Compression=lzma
SolidCompression=yes
WizardStyle=modern
ArchitecturesInstallIn64BitMode=x64compatible
SetupIconFile=windows\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\Jahan_Bit.exe
UninstallDisplayName=Jahan Bit
VersionInfoVersion=1.0.0.0
VersionInfoCompany=Jahan Bit
VersionInfoDescription=Jahan Bit Setup
VersionInfoProductName=Jahan Bit
PrivilegesRequired=lowest

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "Create a desktop shortcut"; GroupDescription: "Additional icons:"; Flags: unchecked

[Files]
Source: "build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{autoprograms}\Jahan Bit"; Filename: "{app}\Jahan_Bit.exe"
Name: "{autodesktop}\Jahan Bit"; Filename: "{app}\Jahan_Bit.exe"; Tasks: desktopicon

[Run]
Filename: "{app}\Jahan_Bit.exe"; Description: "Launch Jahan Bit"; Flags: nowait postinstall skipifsilent
