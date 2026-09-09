; Inno Setup — Jahan Bit
; 1) Build release first:
;      .\tools\build_windows.ps1
;    or: flutter build windows --release
; 2) Compile this script with Inno Setup Compiler (ISCC).
;
; Flutter Windows needs the whole Release folder:
;   Jahan_Bit.exe + *.dll + data\  (assets / app.so / icudtl.dat)
; Installing only the .exe will not launch.

[Setup]
AppId={{9D14829D-5B3D-4208-BFCA-0A1A2B95C7F1}
AppName=Jahan Bit
AppVersion=1.2.0
AppPublisher=Jahan Bit
AppPublisherURL=https://github.com
AppSupportURL=https://github.com
AppCopyright=Copyright (C) 2026 Jahan Bit
; User-writable path (works with PrivilegesRequired=lowest)
DefaultDirName={localappdata}\Jahan Bit
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
VersionInfoVersion=1.2.0.0
VersionInfoCompany=Jahan Bit
VersionInfoDescription=Jahan Bit Setup
VersionInfoProductName=Jahan Bit
PrivilegesRequired=lowest
CloseApplications=yes

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "Create a desktop shortcut"; GroupDescription: "Additional icons:"; Flags: unchecked

[Files]
; Full Flutter runner (exe + plugins + data\)
; Exclude WebView2 cache folder created when app was run from Release
Source: "build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs; Excludes: "Jahan_Bit.exe.WebView2"

[Icons]
Name: "{autoprograms}\Jahan Bit"; Filename: "{app}\Jahan_Bit.exe"; WorkingDir: "{app}"
Name: "{autodesktop}\Jahan Bit"; Filename: "{app}\Jahan_Bit.exe"; WorkingDir: "{app}"; Tasks: desktopicon

[Run]
Filename: "{app}\Jahan_Bit.exe"; WorkingDir: "{app}"; Description: "Launch Jahan Bit"; Flags: nowait postinstall skipifsilent
