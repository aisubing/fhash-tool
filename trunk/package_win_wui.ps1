<#
.SYNOPSIS
    Build the unpackaged x64 fHash app and package it with Inno Setup.

.DESCRIPTION
    Requires Visual Studio (MSBuild, C++ tools, .NET 10 SDK) and Inno Setup 6 or 7.
    The resulting installer is written to trunk\out\fHash-<version>-x64-setup.exe.

.PARAMETER Version
    Version to show in the installer. Defaults to AssemblyVersion from
    trunk\source\WinUI\Properties\AssemblyInfo.cs with a trailing .0 removed.
#>
[CmdletBinding()]
param(
    [string]$Configuration = "Release",
    [string]$Version = ""
)

$ErrorActionPreference = "Stop"

$TrunkDir = $PSScriptRoot
$RepoRoot = Split-Path -Parent $TrunkDir
$OutDir = Join-Path $TrunkDir "out"
$PublishDir = Join-Path $OutDir "publish"
$NativeOutDir = Join-Path $TrunkDir "x64\$Configuration"

function Find-MSBuild {
    $vswhere = Join-Path ${env:ProgramFiles(x86)} "Microsoft Visual Studio\Installer\vswhere.exe"
    if (-not (Test-Path $vswhere)) {
        throw "vswhere.exe not found. Install Visual Studio with the C++ and .NET desktop workloads."
    }

    $msbuild = & $vswhere -latest -products * -requires Microsoft.Component.MSBuild -find "MSBuild\**\Bin\MSBuild.exe" |
        Select-Object -First 1
    if (-not $msbuild) {
        throw "MSBuild.exe not found via vswhere."
    }

    return @{
        Path = $msbuild
        VsVersion = (& $vswhere -latest -products * -property installationVersion | Select-Object -First 1)
        InstallPath = (& $vswhere -latest -products * -property installationPath | Select-Object -First 1)
    }
}

function Invoke-MSBuild {
    param(
        [string]$Project,
        [string[]]$Targets = @(),
        [hashtable]$Properties = @{}
    )

    $arguments = @($Project, "/m", "/v:minimal", "/nologo")
    if ($Targets.Count -gt 0) {
        $arguments += "/t:" + ($Targets -join ";")
    }
    foreach ($key in $Properties.Keys) {
        $arguments += "/p:$key=$($Properties[$key])"
    }

    Write-Host "> msbuild $Project $($Targets -join ',')"
    & $script:MSBuildPath @arguments
    if ($LASTEXITCODE -ne 0) {
        throw "MSBuild failed for $Project"
    }
}

function Get-AppVersion {
    $assemblyInfo = Join-Path $TrunkDir "source\WinUI\Properties\AssemblyInfo.cs"
    $match = Select-String -Path $assemblyInfo -Pattern 'AssemblyVersion\("([^"]+)"\)' |
        Select-Object -First 1
    if (-not $match) {
        throw "Cannot read AssemblyVersion from $assemblyInfo"
    }

    $fullVersion = $match.Matches[0].Groups[1].Value
    if ($fullVersion -match '^(.*)\.0$') {
        return $matches[1]
    }
    return $fullVersion
}

$msbuildInfo = Find-MSBuild
$script:MSBuildPath = $msbuildInfo.Path
$vsMajor = ([version]$msbuildInfo.VsVersion).Major
$platformToolset = if ($vsMajor -ge 18) { "v145" } else { "v143" }

if (-not $Version) {
    $Version = Get-AppVersion
}
Write-Host "fHash $Version ($Configuration, x64, $platformToolset)"

$commonProperties = @{
    Configuration = $Configuration
    Platform = "x64"
    SolutionDir = $TrunkDir + "\"
    PlatformToolset = $platformToolset
}

# The projects pin Windows SDK 10.0.22621.0; fall back to the latest installed
# SDK when that exact version is not present on the build machine.
$sdkInclude = Join-Path ${env:ProgramFiles(x86)} "Windows Kits\10\Include"
if (-not (Test-Path (Join-Path $sdkInclude "10.0.22621.0"))) {
    $commonProperties["WindowsTargetPlatformVersion"] = "10.0"
}

Invoke-MSBuild -Project (Join-Path $RepoRoot "sub-proj\fHashWUINative\fHashWUINative.vcxproj") -Properties $commonProperties
Invoke-MSBuild -Project (Join-Path $RepoRoot "sub-proj\fHashClrBridge\fHashClrBridge.vcxproj") -Properties $commonProperties
Invoke-MSBuild -Project (Join-Path $RepoRoot "sub-proj\fHashWUIShellExt\fHashWUIShellExt.vcxproj") -Properties $commonProperties

Remove-Item $PublishDir -Recurse -Force -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Path $PublishDir -Force | Out-Null
New-Item -ItemType Directory -Path $OutDir -Force | Out-Null

$appProject = Join-Path $TrunkDir "source\WinUI\fHashWUI.csproj"
Invoke-MSBuild -Project $appProject -Targets @("Restore") -Properties $commonProperties

$publishProperties = $commonProperties.Clone()
$publishProperties["RuntimeIdentifier"] = "win-x64"
$publishProperties["SelfContained"] = "true"
$publishProperties["WindowsPackageType"] = "None"
$publishProperties["PublishDir"] = $PublishDir + "\"
Invoke-MSBuild -Project $appProject -Targets @("Publish") -Properties $publishProperties

$bridgeDll = Join-Path $NativeOutDir "fHashClrBridge\fHashClrBridge.dll"
$shellExtDll = Join-Path $NativeOutDir "fHashWUIShellExt\fHashWUIShellExt.dll"
foreach ($file in @($bridgeDll, $shellExtDll)) {
    if (-not (Test-Path $file)) {
        throw "Build output not found: $file"
    }
    Copy-Item $file $PublishDir -Force
}

# The C++/CLI bridge is always built against the DLL CRT; ship it app-local so
# the installer does not need an elevated VC++ Redistributable install.
$crtSource = Get-ChildItem -Path (Join-Path $msbuildInfo.InstallPath "VC\Redist\MSVC") -Directory -ErrorAction SilentlyContinue |
    ForEach-Object { Join-Path $_.FullName "x64" } |
    ForEach-Object { Get-ChildItem -Path $_ -Directory -Filter "Microsoft.VC*.CRT" -ErrorAction SilentlyContinue } |
    Sort-Object FullName |
    Select-Object -Last 1
if ($crtSource) {
    Copy-Item (Join-Path $crtSource.FullName "*.dll") $PublishDir -Force
}
else {
    Write-Warning "VC++ runtime DLLs were not found; install the VC++ Redistributable on the target machine."
}

if (-not (Test-Path (Join-Path $PublishDir "fHashWUI.exe"))) {
    throw "Publish output is missing fHashWUI.exe."
}

$iscc = Get-ChildItem -Path @(${env:ProgramFiles(x86)}, $env:ProgramFiles) -Directory -Filter "Inno Setup *" -ErrorAction SilentlyContinue |
    ForEach-Object { Join-Path $_.FullName "ISCC.exe" } |
    Where-Object { Test-Path $_ } |
    Select-Object -Last 1
if (-not $iscc) {
    throw "ISCC.exe not found. Install Inno Setup 6 or 7 (or run 'choco install innosetup')."
}

$env:FHASH_VERSION = $Version
$env:FHASH_PUBLISH_DIR = $PublishDir
& $iscc (Join-Path $RepoRoot "installer\fhash.iss")
if ($LASTEXITCODE -ne 0) {
    throw "Inno Setup compilation failed."
}

$installer = Join-Path $OutDir "fHash-$Version-x64-setup.exe"
if (-not (Test-Path $installer)) {
    throw "Installer was not produced: $installer"
}

Write-Host ""
Write-Host "Installer: $installer"
