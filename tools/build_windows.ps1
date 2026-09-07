#Requires -Version 5.1
<#
.SYNOPSIS
  Build Windows release into dist\windows (from this project path)

.EXAMPLE
  .\tools\build_windows.ps1
  .\tools\build_windows.ps1 -Installer
#>
[CmdletBinding()]
param(
  [switch]$Installer,
  [switch]$NoClean
)

$ErrorActionPreference = 'Stop'
$Root = Resolve-Path (Join-Path $PSScriptRoot '..')
Set-Location -LiteralPath $Root

function Write-Step([string]$Message) {
  Write-Host ""
  Write-Host "== $Message" -ForegroundColor Cyan
}

function Invoke-Flutter([string[]]$Args) {
  Write-Host (">> flutter " + ($Args -join ' ')) -ForegroundColor DarkGray
  & flutter @Args
  if ($LASTEXITCODE -ne 0) {
    throw "flutter $($Args -join ' ') failed (exit $LASTEXITCODE)"
  }
}

function Find-Iscc {
  foreach ($c in @(
      "${env:LocalAppData}\Programs\Inno Setup 6\ISCC.exe",
      "${env:ProgramFiles(x86)}\Inno Setup 6\ISCC.exe",
      "${env:ProgramFiles}\Inno Setup 6\ISCC.exe"
    )) {
    if (Test-Path -LiteralPath $c) { return $c }
  }
  $cmd = Get-Command ISCC.exe -ErrorAction SilentlyContinue
  if ($cmd) { return $cmd.Source }
  return $null
}

function Remove-DirSafe([string]$Path) {
  if (-not (Test-Path -LiteralPath $Path)) { return }
  # Support long paths leftover from plugins
  cmd /c "rmdir /s /q `"\\?\$Path`"" 2>$null | Out-Null
  if (Test-Path -LiteralPath $Path) {
    Remove-Item -LiteralPath $Path -Recurse -Force -ErrorAction SilentlyContinue
  }
}

if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
  Write-Host "[X] flutter not found in PATH." -ForegroundColor Red
  exit 1
}

Write-Step "Windows release — project path"
Write-Host "Root: $Root"

if (-not $NoClean) {
  Write-Step "Clean CMake / ephemeral cache"
  foreach ($p in @(
      (Join-Path $Root 'build\windows'),
      (Join-Path $Root 'windows\flutter\ephemeral'),
      (Join-Path $Root 'linux\flutter\ephemeral'),
      (Join-Path $Root 'macos\Flutter\ephemeral')
    )) {
    Remove-DirSafe $p
    Write-Host "  cleaned: $p" -ForegroundColor DarkGray
  }
}

Invoke-Flutter @('pub', 'get')
Write-Step "flutter build windows --release"
Invoke-Flutter @('build', 'windows', '--release')

$releaseDir = Join-Path $Root 'build\windows\x64\runner\Release'
$exe = Join-Path $releaseDir 'Jahan_Bit.exe'
if (-not (Test-Path -LiteralPath $exe)) {
  Write-Host "[X] Output not found: $exe" -ForegroundColor Red
  exit 1
}

$distWin = Join-Path $Root 'dist\windows'
Write-Step "Copy Release -> dist\windows"
if (Test-Path -LiteralPath $distWin) {
  Remove-Item -LiteralPath $distWin -Recurse -Force -ErrorAction SilentlyContinue
}
New-Item -ItemType Directory -Force -Path $distWin | Out-Null

Get-ChildItem -LiteralPath $releaseDir -Force | Where-Object {
  $_.Name -notlike '*.WebView2' -and $_.Name -ne 'Jahan_Bit.exe.WebView2'
} | ForEach-Object {
  Copy-Item -LiteralPath $_.FullName -Destination $distWin -Recurse -Force
}

Write-Host "[OK] $(Join-Path $distWin 'Jahan_Bit.exe')" -ForegroundColor Green

if ($Installer) {
  Write-Step "Inno Setup installer"
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
