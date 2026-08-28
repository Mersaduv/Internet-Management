; Inno Setup script — Abar Tawseeh ICT (شرکت خدمات تکنالوژی ابر توسعه)
; Build Windows release first:
;   cd D:\im
;   flutter build windows --release
; Then compile this script with Inno Setup.

[Setup]
AppId={{9D14829D-5B3D-4208-BFCA-0A1A2B95C7F1}
AppName=Abar Tawseeh ICT
AppVersion=1.2.0
AppPublisher=Abar Tawseeh ICT
AppPublisherURL=https://github.com
AppSupportURL=https://github.com
AppCopyright=Copyright (C) 2026 Abar Tawseeh ICT
DefaultDirName={autopf}\Abar Tawseeh ICT
DefaultGroupName=Abar Tawseeh ICT
DisableProgramGroupPage=yes
OutputDir=dist\installer
OutputBaseFilename=Abar_Tawseeh_ICT-Setup
Compression=lzma
SolidCompression=yes
WizardStyle=modern
ArchitecturesInstallIn64BitMode=x64compatible
SetupIconFile=windows\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\Abar_Tawseeh_ICT.exe
UninstallDisplayName=Abar Tawseeh ICT
VersionInfoVersion=1.2.0.0
VersionInfoCompany=Abar Tawseeh ICT
VersionInfoDescription=Abar Tawseeh ICT Setup
VersionInfoProductName=Abar Tawseeh ICT
PrivilegesRequired=lowest

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "Create a desktop shortcut"; GroupDescription: "Additional icons:"; Flags: unchecked

[Files]
Source: "build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{autoprograms}\Abar Tawseeh ICT"; Filename: "{app}\Abar_Tawseeh_ICT.exe"
Name: "{autodesktop}\Abar Tawseeh ICT"; Filename: "{app}\Abar_Tawseeh_ICT.exe"; Tasks: desktopicon

[Run]
Filename: "{app}\Abar_Tawseeh_ICT.exe"; Description: "Launch Abar Tawseeh ICT"; Flags: nowait postinstall skipifsilent
