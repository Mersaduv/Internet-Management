#Requires -Version 5.1
<#
.SYNOPSIS
  Build Windows release via short path D:\jbit, then copy output to dist\windows.

.DESCRIPTION
  Long project paths can break Flutter Windows builds (CMake/MSBuild path limits).
  This script syncs the project to D:\jbit, builds there, and copies Release back.

.EXAMPLE
  .\tools\build_windows.ps1
  .\tools\build_windows.ps1 -Installer
  .\tools\build_windows.ps1 -NoClean
#>
[CmdletBinding()]
param(
  [switch]$NoClean,
  [switch]$Installer,
  [switch]$SkipIcons
)

$ErrorActionPreference = 'Stop'

function Write-Step([string]$Message) {
  Write-Host ""
  Write-Host "== $Message" -ForegroundColor Cyan
}

function Invoke-Flutter([string[]]$FlutterArgs) {
  Write-Host (">> flutter " + ($FlutterArgs -join ' ')) -ForegroundColor DarkGray
  & flutter @FlutterArgs
  if ($LASTEXITCODE -ne 0) {
    throw "flutter $($FlutterArgs -join ' ') failed (exit $LASTEXITCODE)"
  }
}

function Find-Iscc {
  $candidates = @(
    "${env:LocalAppData}\Programs\Inno Setup 6\ISCC.exe",
    "${env:ProgramFiles(x86)}\Inno Setup 6\ISCC.exe",
    "${env:ProgramFiles}\Inno Setup 6\ISCC.exe",
    "${env:ProgramFiles(x86)}\Inno Setup 5\ISCC.exe"
  )
  foreach ($c in $candidates) {
    if (Test-Path -LiteralPath $c) { return $c }
  }
  $cmd = Get-Command ISCC.exe -ErrorAction SilentlyContinue
  if ($cmd) { return $cmd.Source }
  return $null
}

function Remove-EphemeralCaches([string]$ProjectRoot) {
  $paths = @(
    (Join-Path $ProjectRoot 'windows\flutter\ephemeral'),
    (Join-Path $ProjectRoot 'linux\flutter\ephemeral'),
    (Join-Path $ProjectRoot 'macos\Flutter\ephemeral'),
    (Join-Path $ProjectRoot 'ios\Flutter\ephemeral')
  )
  foreach ($p in $paths) {
    if (Test-Path -LiteralPath $p) {
      Remove-Item -LiteralPath $p -Recurse -Force -ErrorAction SilentlyContinue
      Write-Host "  cleaned ephemeral: $p" -ForegroundColor DarkGray
    }
  }
}

function Sync-ToShortPath([string]$SourceRoot, [string]$ShortRoot) {
  Write-Step "Sync project to short path: $ShortRoot"
  if (Test-Path -LiteralPath $ShortRoot) {
    Write-Host "  removing existing $ShortRoot ..." -ForegroundColor DarkGray
    Remove-Item -LiteralPath $ShortRoot -Recurse -Force
  }
  New-Item -ItemType Directory -Path $ShortRoot -Force | Out-Null

  # Exclude build artifacts and ephemeral (robocopy turns symlinks into real dirs
  # which then crash flutter plugin symlink creation with errno 183).
  $xd = @('build', '.dart_tool', 'dist', 'ephemeral', '.plugin_symlinks')
  $args = @($SourceRoot, $ShortRoot, '/E', '/XD') + $xd + @('/NFL', '/NDL', '/NJH', '/NJS', '/nc', '/ns', '/np')
  & robocopy @args | Out-Null
  $code = $LASTEXITCODE
  # robocopy: 0-7 = success (bit flags), >=8 = error
  if ($code -ge 8) {
    throw "robocopy failed with exit code $code"
  }
  Write-Host "  robocopy OK (exit $code)" -ForegroundColor DarkGray

  # Extra safety: remove any ephemeral that slipped through
  Remove-EphemeralCaches $ShortRoot
}

$Root = Resolve-Path (Join-Path $PSScriptRoot '..')
$ShortRoot = 'D:\jbit'

if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
  Write-Host "[X] flutter not found in PATH." -ForegroundColor Red
  exit 1
}

Write-Step "Windows build - Jahan Bit (via short path)"
Write-Host "Source root: $Root"
Write-Host "Build root:  $ShortRoot"

Sync-ToShortPath -SourceRoot $Root -ShortRoot $ShortRoot
Set-Location -LiteralPath $ShortRoot

Invoke-Flutter @('pub', 'get')

if (-not $SkipIcons) {
  try {
    & dart run flutter_launcher_icons 2>$null
  } catch { }
}

if (-not $NoClean) {
  Write-Step "Clean CMake / ephemeral cache on short path"
  foreach ($p in @(
      (Join-Path $ShortRoot 'build\windows'),
      (Join-Path $ShortRoot 'windows\flutter\ephemeral')
    )) {
    if (Test-Path -LiteralPath $p) {
      Remove-Item -LiteralPath $p -Recurse -Force -ErrorAction SilentlyContinue
      Write-Host "  cleaned: $p" -ForegroundColor DarkGray
    }
  }
}

Write-Step "flutter build windows --release"
Invoke-Flutter @('build', 'windows', '--release')

$releaseDir = Join-Path $ShortRoot 'build\windows\x64\runner\Release'
$exe = Join-Path $releaseDir 'Jahan_Bit.exe'
if (-not (Test-Path -LiteralPath $exe)) {
  Write-Host "[X] Output not found: $exe" -ForegroundColor Red
  exit 1
}

$distTargets = @(
  (Join-Path $ShortRoot 'dist\windows'),
  (Join-Path $Root 'dist\windows')
)

Write-Step "Copy Release to dist\windows"
foreach ($distWin in $distTargets) {
  if (-not (Test-Path -LiteralPath $distWin)) {
    New-Item -ItemType Directory -Path $distWin -Force | Out-Null
  }
  Copy-Item -Path (Join-Path $releaseDir '*') -Destination $distWin -Recurse -Force
  Write-Host "[OK] Copied: $distWin\Jahan_Bit.exe" -ForegroundColor Green
}

$fi = Get-Item -LiteralPath $exe
Write-Host "[OK] $exe ($([math]::Round($fi.Length/1KB, 1)) KB)" -ForegroundColor Green

if ($Installer) {
  Write-Step "Inno Setup"
  Set-Location -LiteralPath $Root
  $iscc = Find-Iscc
  $iss = Join-Path $Root 'Jahan_Bit.iss'
  if (-not $iscc) {
    Write-Host "[!] ISCC.exe not found. Install Inno Setup 6." -ForegroundColor Yellow
    exit 1
  }
  & $iscc $iss
  if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
  Write-Host "[OK] dist\installer\Jahan_Bit-Setup.exe" -ForegroundColor Green
}

Write-Host ""
Write-Host "Done." -ForegroundColor Green
exit 0
