#Requires -Version 5.1
<#
.SYNOPSIS
  بیلد یک‌جا: Windows + Android (+ iOS در صورت امکان)

.DESCRIPTION
  از ریشهٔ پروژه اجرا کنید. مشکلات رایج ویندوز (فاصلهٔ --release، کش CMake روی درایو اشتباه)
  اینجا خودکار هندل می‌شود.

.EXAMPLE
  .\tools\build_all.ps1

.EXAMPLE
  .\tools\build_all.ps1 -SkipAndroid
  .\tools\build_all.ps1 -WindowsOnly
  .\tools\build_all.ps1 -NoClean
  .\tools\build_all.ps1 -Installer
#>
[CmdletBinding()]
param(
  [switch]$WindowsOnly,
  [switch]$AndroidOnly,
  [switch]$SkipWindows,
  [switch]$SkipAndroid,
  [switch]$SkipIos,
  [switch]$NoClean,
  [switch]$Installer,
  [switch]$SkipIcons
)

$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

function Write-Step([string]$Message) {
  Write-Host ""
  Write-Host "══════════════════════════════════════════════════════" -ForegroundColor Cyan
  Write-Host "  $Message" -ForegroundColor Cyan
  Write-Host "══════════════════════════════════════════════════════" -ForegroundColor Cyan
}

function Write-Ok([string]$Message) {
  Write-Host "[OK] $Message" -ForegroundColor Green
}

function Write-Warn([string]$Message) {
  Write-Host "[!] $Message" -ForegroundColor Yellow
}

function Write-Fail([string]$Message) {
  Write-Host "[X] $Message" -ForegroundColor Red
}

function Invoke-Flutter {
  param([Parameter(Mandatory)][string[]]$FlutterArgs)
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
  if (-not $line) { return @{ Name = '1.0.0'; Build = '1'; Full = '1.0.0+1' } }
  $raw = ($line -replace '^\s*version:\s*', '').Trim()
  $parts = $raw.Split('+')
  return @{
    Name  = $parts[0]
    Build = $(if ($parts.Count -gt 1) { $parts[1] } else { '1' })
    Full  = $raw
  }
}

function Ensure-Dir([string]$Path) {
  if (-not (Test-Path -LiteralPath $Path)) {
    New-Item -ItemType Directory -Path $Path -Force | Out-Null
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

# —— مسیر ریشه پروژه (پوشهٔ والد tools)
$Root = Resolve-Path (Join-Path $PSScriptRoot '..')
Set-Location -LiteralPath $Root

if ($WindowsOnly) {
  $SkipAndroid = $true
  $SkipIos = $true
}
if ($AndroidOnly) {
  $SkipWindows = $true
  $SkipIos = $true
}

$IsWindowsHost = [bool]($env:OS -eq 'Windows_NT')
# روی ویندوز iOS را پیش‌فرض رد کن مگر کاربر صریحاً -SkipIos:$false بدهد
if ($IsWindowsHost -and -not $PSBoundParameters.ContainsKey('SkipIos')) {
  $SkipIos = $true
}

$ver = Get-AppVersion
$results = [ordered]@{}
$started = Get-Date

Write-Step "Jahan Bit build — v$($ver.Full)"
Write-Host "Root: $Root"
Write-Host "Windows: $(-not $SkipWindows) | Android: $(-not $SkipAndroid) | iOS: $(-not $SkipIos) | Installer: $Installer"

# —— پیش‌نیاز
Write-Step "1) flutter pub get"
$flutterCmd = Get-Command flutter -ErrorAction SilentlyContinue
if (-not $flutterCmd) {
  Write-Fail "flutter در PATH پیدا نشد. Flutter SDK را نصب/در PATH بگذارید."
  exit 1
}
Invoke-Flutter @('pub', 'get')

if (-not $SkipIcons) {
  Write-Step "2) launcher icons (اختیاری)"
  try {
    Write-Host ">> dart run flutter_launcher_icons" -ForegroundColor DarkGray
    & dart run flutter_launcher_icons
    if ($LASTEXITCODE -ne 0) {
      Write-Warn "ساخت آیکون رد شد (ادامه می‌دهیم)."
    } else {
      Write-Ok "آیکون‌ها به‌روز شد"
    }
  } catch {
    Write-Warn "ساخت آیکون رد شد: $($_.Exception.Message)"
  }
}

# —— Windows
if (-not $SkipWindows) {
  Write-Step "3) Windows release"
  try {
    if (-not $NoClean) {
      Write-Host "پاک‌سازی کش CMake / ephemeral (رفع خطای رایج درایو اشتباه)..."
      $cleanPaths = @(
        (Join-Path $Root 'build\windows'),
        (Join-Path $Root 'windows\flutter\ephemeral')
      )
      foreach ($p in $cleanPaths) {
        if (Test-Path -LiteralPath $p) {
          Remove-Item -LiteralPath $p -Recurse -Force -ErrorAction SilentlyContinue
          Write-Host "  cleaned: $p" -ForegroundColor DarkGray
        }
      }
    }

    # مهم: بین windows و --release حتماً فاصله باشد
    Invoke-Flutter @('build', 'windows', '--release')

    $releaseDir = Join-Path $Root 'build\windows\x64\runner\Release'
    $exe = Join-Path $releaseDir 'Jahan_Bit.exe'
    if (-not (Test-Path -LiteralPath $exe)) {
      throw "خروجی پیدا نشد: $exe"
    }

    $distWin = Join-Path $Root 'dist\windows'
    Ensure-Dir $distWin
    Write-Host "کپی به dist\windows ..."
    Copy-Item -Path (Join-Path $releaseDir '*') -Destination $distWin -Recurse -Force
    Write-Ok "Windows: $exe"
    Write-Ok "کپی: $distWin\Jahan_Bit.exe"
    $results['Windows'] = 'OK'

    if ($Installer) {
      Write-Step "3b) Inno Setup installer"
      $iscc = Find-Iscc
      $iss = Join-Path $Root 'Jahan_Bit.iss'
      if (-not $iscc) {
        Write-Warn "ISCC.exe پیدا نشد. Inno Setup 6 را نصب کنید یا Setup را دستی بسازید."
        $results['Installer'] = 'SKIPPED'
      } elseif (-not (Test-Path -LiteralPath $iss)) {
        Write-Warn "فایل $iss پیدا نشد."
        $results['Installer'] = 'SKIPPED'
      } else {
        Write-Host ">> `"$iscc`" `"$iss`"" -ForegroundColor DarkGray
        & $iscc $iss
        if ($LASTEXITCODE -ne 0) {
          throw "Inno Setup failed (exit $LASTEXITCODE)"
        }
        $setup = Join-Path $Root 'dist\installer\Jahan_Bit-Setup.exe'
        if (Test-Path -LiteralPath $setup) {
          Write-Ok "Installer: $setup"
          $results['Installer'] = 'OK'
        } else {
          Write-Warn "بیلد Setup تمام شد ولی فایل خروجی دیده نشد."
          $results['Installer'] = 'WARN'
        }
      }
    }
  } catch {
    Write-Fail "Windows: $($_.Exception.Message)"
    $results['Windows'] = 'FAIL'
  }
} else {
  $results['Windows'] = 'SKIPPED'
}

# —— Android
if (-not $SkipAndroid) {
  Write-Step "4) Android APK release"
  try {
    Invoke-Flutter @('build', 'apk', '--release')

    $apkSrc = Join-Path $Root 'build\app\outputs\flutter-apk\app-release.apk'
    if (-not (Test-Path -LiteralPath $apkSrc)) {
      throw "APK پیدا نشد: $apkSrc"
    }

    $distApk = Join-Path $Root 'dist\android'
    Ensure-Dir $distApk
    $apkName = "Jahan_Bit-v$($ver.Name)($($ver.Build))-release.apk"
    $apkDest = Join-Path $distApk $apkName
    Copy-Item -LiteralPath $apkSrc -Destination $apkDest -Force
    Write-Ok "Android: $apkDest"
    $results['Android'] = 'OK'
  } catch {
    Write-Fail "Android: $($_.Exception.Message)"
    $results['Android'] = 'FAIL'
  }
} else {
  $results['Android'] = 'SKIPPED'
}

# —— iOS (عملاً فقط روی macOS)
if (-not $SkipIos) {
  Write-Step "5) iOS IPA"
  if ($IsWindowsHost) {
    Write-Warn "بیلد iOS روی ویندوز ممکن نیست. از macOS یا GitHub Actions استفاده کنید."
    $results['iOS'] = 'SKIPPED (Windows host)'
  } else {
    try {
      Invoke-Flutter @('build', 'ios', '--release', '--no-codesign')
      $pkg = Join-Path $Root 'tools\package_ipa.sh'
      if (Test-Path -LiteralPath $pkg) {
        & bash $pkg
        if ($LASTEXITCODE -ne 0) { throw "package_ipa.sh failed" }
      }
      Write-Ok "iOS IPA ساخته شد (ریشه پروژه / CI)"
      $results['iOS'] = 'OK'
    } catch {
      Write-Fail "iOS: $($_.Exception.Message)"
      $results['iOS'] = 'FAIL'
    }
  }
} else {
  if ($IsWindowsHost) {
    $results['iOS'] = 'SKIPPED (use macOS / CI)'
  } else {
    $results['iOS'] = 'SKIPPED'
  }
}

# —— خلاصه
$elapsed = (Get-Date) - $started
Write-Step "خلاصه بیلد ($([int]$elapsed.TotalMinutes)m $($elapsed.Seconds)s)"
foreach ($k in $results.Keys) {
  $v = $results[$k]
  $color = switch -Wildcard ($v) {
    'OK' { 'Green' }
    'FAIL' { 'Red' }
    'WARN' { 'Yellow' }
    default { 'DarkYellow' }
  }
  Write-Host ("  {0,-12} {1}" -f $k, $v) -ForegroundColor $color
}

Write-Host ""
Write-Host "خروجی‌ها:" -ForegroundColor Cyan
Write-Host "  Windows exe : dist\windows\Jahan_Bit.exe"
Write-Host "  Windows raw : build\windows\x64\runner\Release\"
Write-Host "  Android APK : dist\android\Jahan_Bit-v$($ver.Name)($($ver.Build))-release.apk"
Write-Host "  Installer   : dist\installer\Jahan_Bit-Setup.exe  (با -Installer)"
Write-Host ""

$failed = @($results.Values | Where-Object { $_ -eq 'FAIL' })
if ($failed.Count -gt 0) {
  Write-Fail "حداقل یک بیلد شکست خورد."
  exit 1
}

Write-Ok "تمام شد."
exit 0
