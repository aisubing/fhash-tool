; fHash traditional installer.
; Build with ISCC after staging the unpackaged, self-contained publish output.
; FHASH_VERSION      - version shown in the wizard and file name (e.g. 26.10.56)
; FHASH_PUBLISH_DIR  - directory containing fHashWUI.exe and the runtime files

#define MyAppName "fHash"
#define MyAppExeName "fHashWUI.exe"
#define MyAppPublisher "SUN Junwen"
#define MyAppURL "https://github.com/aisubing/fhash-tool"

#define MyAppVersion GetEnv("FHASH_VERSION")
#if MyAppVersion == ""
  #define MyAppVersion "0.0.0"
#endif

#define PublishDir GetEnv("FHASH_PUBLISH_DIR")
#if PublishDir == ""
  #define PublishDir SourcePath + "\..\trunk\out\publish"
#endif

#define RepoRoot SourcePath + "\.."

#if !DirExists(PublishDir)
  #error "Publish directory not found. Set FHASH_PUBLISH_DIR or build with trunk/package_win_wui.ps1."
#endif
#if !FileExists(AddBackslash(PublishDir) + "fHashWUIShellExt.dll")
  #error "fHashWUIShellExt.dll is missing from the publish directory."
#endif
#if !FileExists(RepoRoot + "\trunk\source\WinUI\Assets\fHashWUI.ico")
  #error "fHashWUI.ico not found. Run the script from the repository."
#endif

[Setup]
AppId={{7F1B6C24-3D5A-4E8B-9C21-5A0D8E6F3B47}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppVerName={#MyAppName} {#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}
AppSupportURL={#MyAppURL}
AppUpdatesURL={#MyAppURL}/releases
AppCopyright=Copyright (C) 2007- SUN Junwen
DefaultDirName={localappdata}\Programs\fHash
DefaultGroupName={#MyAppName}
DisableProgramGroupPage=yes
PrivilegesRequired=lowest
LicenseFile={#RepoRoot}\LICENSE
OutputDir={#SourcePath}\..\trunk\out
OutputBaseFilename=fHash-{#MyAppVersion}-x64-setup
SetupIconFile={#RepoRoot}\trunk\source\WinUI\Assets\fHashWUI.ico
UninstallDisplayIcon={app}\{#MyAppExeName}
Compression=lzma2/max
SolidCompression=yes
WizardStyle=modern
ArchitecturesAllowed=x64os
ArchitecturesInstallIn64BitMode=x64os
MinVersion=10.0.18362
CloseApplications=yes
RestartApplications=no
VersionInfoVersion={#MyAppVersion}
VersionInfoProductName={#MyAppName}
VersionInfoDescription={#MyAppName} Setup

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
Source: "{#PublishDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs; Excludes: "*.pdb"

[Icons]
Name: "{autoprograms}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Registry]
; Read by the Explorer context menu extension to locate fHashWUI.exe.
Root: HKCU; Subkey: "Software\fHash"; ValueType: string; ValueName: "InstallPath"; ValueData: "{app}"; Flags: uninsdeletekey
Root: HKCU; Subkey: "Software\Microsoft\Windows\CurrentVersion\App Paths\fHashWUI.exe"; ValueType: string; ValueName: ""; ValueData: "{app}\{#MyAppExeName}"; Flags: uninsdeletekey

[Run]
Filename: "{sys}\regsvr32.exe"; Parameters: "/s ""{app}\fHashWUIShellExt.dll"""; StatusMsg: "Registering Explorer context menu..."; Flags: runhidden waituntilterminated
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#StringChange(MyAppName, '&', '&&')}}"; Flags: nowait postinstall skipifsilent

[UninstallRun]
Filename: "{sys}\regsvr32.exe"; Parameters: "/u /s ""{app}\fHashWUIShellExt.dll"""; RunOnceId: "UnregisterShellExt"; Flags: runhidden waituntilterminated

[UninstallDelete]
Type: filesandordirs; Name: "{app}"
