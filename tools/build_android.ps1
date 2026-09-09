#Requires -Version 5.1
<#
.SYNOPSIS
  Build Android release APK into dist\android

.EXAMPLE
  .\tools\build_android.ps1
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$Root = Resolve-Path (Join-Path $PSScriptRoot '..')
Set-Location -LiteralPath $Root

function Write-Step([string]$Message) {
  Write-Host ""
  Write-Host ("== {0}" -f $Message) -ForegroundColor Cyan
}

function Invoke-Flutter([string[]]$FlutterArgs) {
  Write-Host (">> flutter {0}" -f ($FlutterArgs -join ' ')) -ForegroundColor DarkGray
  & flutter @FlutterArgs
  if ($LASTEXITCODE -ne 0) {
    throw ("flutter {0} failed (exit {1})" -f ($FlutterArgs -join ' '), $LASTEXITCODE)
  }
}

function Get-AppVersion {
  $line = Get-Content (Join-Path $Root 'pubspec.yaml') |
    Where-Object { $_ -match '^\s*version:\s*' } |
    Select-Object -First 1
  $raw = if ($line) { ($line -replace '^\s*version:\s*', '').Trim() } else { '1.0.0+1' }
  $parts = $raw.Split('+')
  return @{
    Name  = $parts[0]
    Build = $(if ($parts.Count -gt 1) { $parts[1] } else { '1' })
    Full  = $raw
  }
}

if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
  Write-Host '[X] flutter not found in PATH.' -ForegroundColor Red
  exit 1
}

$ver = Get-AppVersion
Write-Step ("Android APK - v{0}" -f $ver.Full)
Write-Host ("Root: {0}" -f $Root)

Invoke-Flutter @('pub', 'get')
Write-Step 'flutter build apk --release'
Invoke-Flutter @('build', 'apk', '--release')

$apkSrc = Join-Path $Root 'build\app\outputs\flutter-apk\app-release.apk'
if (-not (Test-Path -LiteralPath $apkSrc)) {
  Write-Host ("[X] APK not found: {0}" -f $apkSrc) -ForegroundColor Red
  exit 1
}

$distDir = Join-Path $Root 'dist\android'
New-Item -ItemType Directory -Force -Path $distDir | Out-Null
$apkName = "Jahan_Bit-v{0}({1})-release.apk" -f $ver.Name, $ver.Build
$apkDest = Join-Path $distDir $apkName
Copy-Item -LiteralPath $apkSrc -Destination $apkDest -Force

Write-Host ("[OK] {0}" -f $apkDest) -ForegroundColor Green
exit 0
