#Requires -Version 5.1
<#
.SYNOPSIS
  بیلد فقط Android APK (release) + کپی به dist\android

.EXAMPLE
  .\tools\build_android.ps1
#>
[CmdletBinding()]
param(
  [switch]$SkipIcons
)

$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

function Write-Step([string]$Message) {
  Write-Host ""
  Write-Host "══ $Message" -ForegroundColor Cyan
}

function Invoke-Flutter([string[]]$FlutterArgs) {
  Write-Host (">> flutter " + ($FlutterArgs -join ' ')) -ForegroundColor DarkGray
  & flutter @FlutterArgs
  if ($LASTEXITCODE -ne 0) {
    throw "flutter $($FlutterArgs -join ' ') failed (exit $LASTEXITCODE)"
  }
}

function Get-AppVersion {
  $line = Get-Content -Path (Join-Path $Root 'pubspec.yaml') |
    Where-Object { $_ -match '^\s*version:\s*' } |
    Select-Object -First 1
  if (-not $line) { return @{ Name = '1.0.0'; Build = '1' } }
  $raw = ($line -replace '^\s*version:\s*', '').Trim()
  $parts = $raw.Split('+')
  return @{
    Name  = $parts[0]
    Build = $(if ($parts.Count -gt 1) { $parts[1] } else { '1' })
  }
}

$Root = Resolve-Path (Join-Path $PSScriptRoot '..')
Set-Location -LiteralPath $Root

if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
  Write-Host "[X] flutter در PATH نیست." -ForegroundColor Red
  exit 1
}

$ver = Get-AppVersion
Write-Step "Android APK build — v$($ver.Name)+$($ver.Build)"
Write-Host "Root: $Root"

Invoke-Flutter @('pub', 'get')

if (-not $SkipIcons) {
  try {
    & dart run flutter_launcher_icons 2>$null
  } catch { }
}

Write-Step "flutter build apk --release"
Invoke-Flutter @('build', 'apk', '--release')

$apkSrc = Join-Path $Root 'build\app\outputs\flutter-apk\app-release.apk'
if (-not (Test-Path -LiteralPath $apkSrc)) {
  Write-Host "[X] APK پیدا نشد: $apkSrc" -ForegroundColor Red
  exit 1
}

$distApk = Join-Path $Root 'dist\android'
if (-not (Test-Path -LiteralPath $distApk)) {
  New-Item -ItemType Directory -Path $distApk -Force | Out-Null
}
$apkName = "Jahan_Bit-v$($ver.Name)($($ver.Build))-release.apk"
$apkDest = Join-Path $distApk $apkName
Copy-Item -LiteralPath $apkSrc -Destination $apkDest -Force

Write-Host "[OK] $apkDest" -ForegroundColor Green
Write-Host ""
Write-Host "تمام شد." -ForegroundColor Green
exit 0
