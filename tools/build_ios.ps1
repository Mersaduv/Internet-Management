#Requires -Version 5.1
<#
.SYNOPSIS
  Build / fetch iOS IPA into dist\ios

.DESCRIPTION
  - On macOS: local unsigned IPA build
  - On Windows: waits for GitHub Actions (Build iOS IPA) for current HEAD,
    then downloads the release IPA into dist\ios

  Push to master first so CI runs (paths under lib/, ios/, pubspec*).

.EXAMPLE
  .\tools\build_ios.ps1
  .\tools\build_ios.ps1 -TimeoutMinutes 45
#>
[CmdletBinding()]
param(
  [int]$TimeoutMinutes = 45,
  [string]$Repo = 'Mersaduv/Internet-Management'
)

$ErrorActionPreference = 'Stop'
$Root = Resolve-Path (Join-Path $PSScriptRoot '..')
Set-Location -LiteralPath $Root

function Write-Step([string]$Message) {
  Write-Host ""
  Write-Host ("== {0}" -f $Message) -ForegroundColor Cyan
}

function Get-AppVersion {
  $line = Get-Content (Join-Path $Root 'pubspec.yaml') |
    Where-Object { $_ -match '^\s*version:\s*' } |
    Select-Object -First 1
  if ($line) {
    return ($line -replace '^\s*version:\s*', '').Trim()
  }
  return '1.0.0+1'
}

function Get-GitSha {
  $sha = (& git rev-parse HEAD 2>$null)
  if (-not $sha) { throw 'git SHA not available' }
  return $sha.Trim()
}

function Invoke-JsonGet([string]$Url) {
  $tmp = Join-Path $env:TEMP ("jahanbit-ios-" + [guid]::NewGuid().ToString() + '.json')
  & curl.exe -sL $Url -o $tmp
  if ($LASTEXITCODE -ne 0) { throw ("curl failed for {0}" -f $Url) }
  $text = Get-Content -LiteralPath $tmp -Raw -Encoding UTF8
  Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue
  return $text | ConvertFrom-Json
}

function Build-IosLocal([string]$Version) {
  Write-Step 'Local iOS build (macOS)'
  if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
    throw 'flutter not found in PATH'
  }
  & flutter pub get
  if ($LASTEXITCODE -ne 0) { throw 'flutter pub get failed' }
  & flutter build ios --release --no-codesign
  if ($LASTEXITCODE -ne 0) { throw 'flutter build ios failed' }

  $app = Join-Path $Root 'build/ios/iphoneos/Runner.app'
  if (-not (Test-Path $app)) { throw ("Missing {0}" -f $app) }

  $ipaName = "Jahan_Bit-$Version.ipa"
  $work = Join-Path $Root 'build/ipa'
  Remove-Item -Recurse -Force $work -ErrorAction SilentlyContinue
  New-Item -ItemType Directory -Force -Path (Join-Path $work 'Payload') | Out-Null
  Copy-Item -Recurse $app (Join-Path $work 'Payload/Runner.app')
  Push-Location $work
  try {
    & zip -r (Join-Path $Root $ipaName) Payload | Out-Null
  } finally {
    Pop-Location
  }

  $dist = Join-Path $Root 'dist/ios'
  New-Item -ItemType Directory -Force -Path $dist | Out-Null
  $dest = Join-Path $dist $ipaName
  Move-Item -Force (Join-Path $Root $ipaName) $dest
  Write-Host ("[OK] {0}" -f $dest) -ForegroundColor Green
}

function Build-IosFromCi([string]$Version, [string]$Sha) {
  $shortSha = $Sha.Substring(0, 7)
  Write-Step ("Wait for GitHub Actions IPA (sha {0})" -f $shortSha)
  Write-Host ("Repo: {0}" -f $Repo)
  Write-Host 'If CI is not running yet, push master (lib/ios/pubspec changes).' -ForegroundColor DarkGray

  $deadline = (Get-Date).AddMinutes($TimeoutMinutes)
  $runId = $null
  $conclusion = $null

  while ((Get-Date) -lt $deadline) {
    $runsUrl = "https://api.github.com/repos/$Repo/actions/workflows/ios-ipa.yml/runs?per_page=10"
    $runs = Invoke-JsonGet $runsUrl
    $match = $runs.workflow_runs | Where-Object { $_.head_sha -eq $Sha } | Select-Object -First 1
    if (-not $match) {
      Write-Host '  waiting for workflow run...' -ForegroundColor DarkGray
      Start-Sleep -Seconds 15
      continue
    }
    $runId = $match.id
    $status = $match.status
    $conclusion = $match.conclusion
    Write-Host ("  run {0} - status={1} conclusion={2}" -f $runId, $status, $conclusion) -ForegroundColor DarkGray
    if ($status -eq 'completed') { break }
    Start-Sleep -Seconds 20
  }

  if (-not $runId) {
    throw ("No CI run found for {0} within {1} minutes." -f $Sha, $TimeoutMinutes)
  }
  if ($conclusion -ne 'success') {
    throw ("CI run {0} finished with conclusion={1}. See https://github.com/{2}/actions/runs/{0}" -f $runId, $conclusion, $Repo)
  }

  $tag = "ios-ipa-$Version"
  $encodedTag = [uri]::EscapeDataString($tag)
  $release = Invoke-JsonGet ("https://api.github.com/repos/{0}/releases/tags/{1}" -f $Repo, $encodedTag)
  $asset = $release.assets | Where-Object { $_.name -like 'Jahan_Bit-*.ipa' } | Select-Object -First 1
  if (-not $asset) {
    throw ("IPA asset not found on release {0}" -f $tag)
  }

  $dist = Join-Path $Root 'dist\ios'
  New-Item -ItemType Directory -Force -Path $dist | Out-Null
  Get-ChildItem -LiteralPath $dist -Filter '*.ipa' -ErrorAction SilentlyContinue |
    Remove-Item -Force -ErrorAction SilentlyContinue

  $dest = Join-Path $dist $asset.name
  Write-Step ("Download {0}" -f $asset.name)
  & curl.exe -L $asset.browser_download_url -o $dest
  if ($LASTEXITCODE -ne 0 -or -not (Test-Path $dest)) {
    throw 'Download failed'
  }
  $sizeMb = [math]::Round((Get-Item -LiteralPath $dest).Length / 1MB, 1)
  Write-Host ('[OK] {0} ({1} MB)' -f $dest, $sizeMb) -ForegroundColor Green
  Write-Host ('CI: https://github.com/{0}/actions/runs/{1}' -f $Repo, $runId) -ForegroundColor DarkGray
}

$version = Get-AppVersion
$isMac = $false
if ($PSVersionTable.PSEdition -eq 'Core' -and $IsMacOS) {
  $isMac = $true
} elseif ($env:OS -notlike '*Windows*') {
  try {
    if ((& uname -s 2>$null) -eq 'Darwin') { $isMac = $true }
  } catch { }
}

Write-Step ("iOS IPA - v{0}" -f $version)
Write-Host ("Root: {0}" -f $Root)

if ($isMac) {
  Build-IosLocal -Version $version
} else {
  $sha = Get-GitSha
  Build-IosFromCi -Version $version -Sha $sha
}

Write-Host ''
Write-Host 'Done.' -ForegroundColor Green
exit 0
