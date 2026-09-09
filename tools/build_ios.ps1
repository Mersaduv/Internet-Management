#Requires -Version 5.1
<#
.SYNOPSIS
  Build / fetch iOS IPA into dist\ios

.DESCRIPTION
  - macOS: local unsigned IPA (flutter build ios --release --no-codesign)
  - Windows: fetch IPA from GitHub Actions / Release into dist\ios

  Windows modes:
  - Default: wait for CI run matching current HEAD, then download release IPA.
    If no matching run appears in time, falls back to the release for pubspec version.
  - -Latest: skip waiting; download release IPA for the current pubspec version.
  - -Sha <hash>: wait for a specific commit SHA instead of HEAD.

  Push to master (lib/, ios/, pubspec*) or use workflow_dispatch so CI can build.

.EXAMPLE
  .\tools\build_ios.ps1
  .\tools\build_ios.ps1 -Latest
  .\tools\build_ios.ps1 -TimeoutMinutes 60
  .\tools\build_ios.ps1 -Sha a031c56c8f94e76d1846b76b0a9d94d265eee7a4
#>
[CmdletBinding()]
param(
  [int]$TimeoutMinutes = 45,
  [string]$Repo = 'Mersaduv/Internet-Management',
  [string]$Sha = '',
  [switch]$Latest
)

$ErrorActionPreference = 'Stop'
$Root = Resolve-Path (Join-Path $PSScriptRoot '..')
Set-Location -LiteralPath $Root

function Write-Step([string]$Message) {
  Write-Host ''
  Write-Host ("== {0}" -f $Message) -ForegroundColor Cyan
}

function Get-AppVersion {
  $line = Get-Content -LiteralPath (Join-Path $Root 'pubspec.yaml') |
    Where-Object { $_ -match '^\s*version:\s*' } |
    Select-Object -First 1
  if ($line) {
    return ($line -replace '^\s*version:\s*', '').Trim()
  }
  return '1.2.0+1'
}

function Get-GitSha {
  $value = (& git rev-parse HEAD 2>$null)
  if (-not $value) { throw 'git SHA not available' }
  return $value.Trim()
}

function Test-IsMacOS {
  if ($PSVersionTable.PSEdition -eq 'Core' -and $IsMacOS) { return $true }
  if ($env:OS -like '*Windows*') { return $false }
  try {
    return ((& uname -s 2>$null) -eq 'Darwin')
  } catch {
    return $false
  }
}

function Assert-Curl {
  if (-not (Get-Command curl.exe -ErrorAction SilentlyContinue)) {
    throw 'curl.exe not found in PATH'
  }
}

function Invoke-JsonGet([string]$Url) {
  Assert-Curl
  $tmp = Join-Path $env:TEMP ('jahanbit-ios-' + [guid]::NewGuid().ToString() + '.json')
  & curl.exe -sSL $Url -o $tmp
  if ($LASTEXITCODE -ne 0) {
    Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue
    throw ("curl failed for {0}" -f $Url)
  }
  $text = Get-Content -LiteralPath $tmp -Raw -Encoding UTF8
  Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue
  if ([string]::IsNullOrWhiteSpace($text)) {
    throw ("Empty response from {0}" -f $Url)
  }
  if ($text -match '"message"\s*:\s*"Not Found"') {
    throw ("Not found: {0}" -f $Url)
  }
  return ($text | ConvertFrom-Json)
}

function Clear-IosDist {
  $dist = Join-Path $Root 'dist\ios'
  New-Item -ItemType Directory -Force -Path $dist | Out-Null
  Get-ChildItem -LiteralPath $dist -Filter '*.ipa' -ErrorAction SilentlyContinue |
    Remove-Item -Force -ErrorAction SilentlyContinue
  return $dist
}

function Save-IpaFromUrl([string]$Url, [string]$FileName) {
  $dist = Clear-IosDist
  $dest = Join-Path $dist $FileName
  Write-Step ("Download {0}" -f $FileName)
  Assert-Curl
  & curl.exe -fL $Url -o $dest
  if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $dest)) {
    throw 'Download failed'
  }
  $sizeMb = [math]::Round((Get-Item -LiteralPath $dest).Length / 1MB, 1)
  if ($sizeMb -lt 0.5) {
    throw ("Downloaded file looks too small ({0} MB): {1}" -f $sizeMb, $dest)
  }
  Write-Host ('[OK] {0} ({1} MB)' -f $dest, $sizeMb) -ForegroundColor Green
  return $dest
}

function Get-ReleaseIpaAsset([string]$Version) {
  $tag = "ios-ipa-$Version"
  $encodedTag = [uri]::EscapeDataString($tag)
  $url = "https://api.github.com/repos/{0}/releases/tags/{1}" -f $Repo, $encodedTag
  Write-Host ("Release tag: {0}" -f $tag) -ForegroundColor DarkGray
  $release = Invoke-JsonGet $url
  $asset = $release.assets | Where-Object { $_.name -like 'Jahan_Bit-*.ipa' } | Select-Object -First 1
  if (-not $asset) {
    throw ("IPA asset not found on release {0}" -f $tag)
  }
  return $asset
}

function Get-LatestSuccessfulIosRun {
  $runsUrl = "https://api.github.com/repos/{0}/actions/workflows/ios-ipa.yml/runs?per_page=20&status=completed" -f $Repo
  $runs = Invoke-JsonGet $runsUrl
  $match = $runs.workflow_runs |
    Where-Object { $_.conclusion -eq 'success' } |
    Select-Object -First 1
  return $match
}

function Wait-IosCiRun([string]$TargetSha) {
  $shortSha = $TargetSha.Substring(0, [Math]::Min(7, $TargetSha.Length))
  Write-Step ("Wait for GitHub Actions IPA (sha {0})" -f $shortSha)
  Write-Host ("Repo: {0}" -f $Repo)
  Write-Host 'Tip: push master (lib/ios/pubspec) or run workflow_dispatch on GitHub.' -ForegroundColor DarkGray

  $deadline = (Get-Date).AddMinutes($TimeoutMinutes)
  $runId = $null
  $conclusion = $null
  $status = $null

  while ((Get-Date) -lt $deadline) {
    $runsUrl = "https://api.github.com/repos/{0}/actions/workflows/ios-ipa.yml/runs?per_page=20" -f $Repo
    $runs = Invoke-JsonGet $runsUrl
    $match = $runs.workflow_runs | Where-Object { $_.head_sha -eq $TargetSha } | Select-Object -First 1

    if (-not $match) {
      Write-Host '  waiting for workflow run...' -ForegroundColor DarkGray
      Start-Sleep -Seconds 15
      continue
    }

    $runId = [string]$match.id
    $status = [string]$match.status
    $conclusion = [string]$match.conclusion
    Write-Host ("  run {0} - status={1} conclusion={2}" -f $runId, $status, $conclusion) -ForegroundColor DarkGray

    if ($status -eq 'completed') { break }
    Start-Sleep -Seconds 20
  }

  if (-not $runId) {
    return $null
  }
  if ($status -ne 'completed') {
    throw ("CI run {0} still running after {1} minutes. See https://github.com/{2}/actions/runs/{0}" -f $runId, $TimeoutMinutes, $Repo)
  }
  if ($conclusion -ne 'success') {
    throw ("CI run {0} finished with conclusion={1}. See https://github.com/{2}/actions/runs/{0}" -f $runId, $conclusion, $Repo)
  }

  return @{
    Id         = $runId
    Conclusion = $conclusion
  }
}

function Wait-ReleaseAsset([string]$Version, [int]$WaitMinutes = 5) {
  $deadline = (Get-Date).AddMinutes($WaitMinutes)
  while ((Get-Date) -lt $deadline) {
    try {
      return (Get-ReleaseIpaAsset -Version $Version)
    } catch {
      Write-Host '  waiting for release asset...' -ForegroundColor DarkGray
      Start-Sleep -Seconds 10
    }
  }
  throw ("IPA release asset not ready for version {0}" -f $Version)
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

  $app = Join-Path $Root 'build\ios\iphoneos\Runner.app'
  if (-not (Test-Path -LiteralPath $app)) {
    throw ("Missing {0}" -f $app)
  }

  $ipaName = "Jahan_Bit-$Version.ipa"
  $work = Join-Path $Root 'build\ipa'
  Remove-Item -Recurse -Force $work -ErrorAction SilentlyContinue
  New-Item -ItemType Directory -Force -Path (Join-Path $work 'Payload') | Out-Null
  Copy-Item -Recurse -Force $app (Join-Path $work 'Payload\Runner.app')

  $zipPath = Join-Path $Root $ipaName
  Remove-Item -Force $zipPath -ErrorAction SilentlyContinue
  Push-Location $work
  try {
    if (Get-Command zip -ErrorAction SilentlyContinue) {
      & zip -r $zipPath Payload | Out-Null
      if ($LASTEXITCODE -ne 0) { throw 'zip failed' }
    } else {
      Compress-Archive -Path 'Payload' -DestinationPath $zipPath -Force
      # Compress-Archive makes .zip; rename if needed
      if ((Test-Path -LiteralPath $zipPath) -eq $false -and (Test-Path -LiteralPath ($zipPath + '.zip'))) {
        Move-Item -Force ($zipPath + '.zip') $zipPath
      }
    }
  } finally {
    Pop-Location
  }

  $dist = Clear-IosDist
  $dest = Join-Path $dist $ipaName
  Move-Item -Force $zipPath $dest
  $sizeMb = [math]::Round((Get-Item -LiteralPath $dest).Length / 1MB, 1)
  Write-Host ('[OK] {0} ({1} MB)' -f $dest, $sizeMb) -ForegroundColor Green
}

function Get-IosFromCiOrRelease([string]$Version, [string]$TargetSha) {
  if ($Latest) {
    Write-Step ("Download latest release IPA (v{0})" -f $Version)
    $asset = Get-ReleaseIpaAsset -Version $Version
    Save-IpaFromUrl -Url $asset.browser_download_url -FileName $asset.name | Out-Null
    $latestRun = Get-LatestSuccessfulIosRun
    if ($latestRun) {
      Write-Host ('Last successful CI: https://github.com/{0}/actions/runs/{1}' -f $Repo, $latestRun.id) -ForegroundColor DarkGray
    }
    return
  }

  $run = Wait-IosCiRun -TargetSha $TargetSha
  if (-not $run) {
    Write-Host ''
    Write-Host ("No CI run for SHA {0} within {1} minutes." -f $TargetSha, $TimeoutMinutes) -ForegroundColor Yellow
    Write-Host 'Falling back to release IPA for current pubspec version...' -ForegroundColor Yellow
    $asset = Get-ReleaseIpaAsset -Version $Version
    Save-IpaFromUrl -Url $asset.browser_download_url -FileName $asset.name | Out-Null
    $latestRun = Get-LatestSuccessfulIosRun
    if ($latestRun) {
      Write-Host ('Last successful CI: https://github.com/{0}/actions/runs/{1}' -f $Repo, $latestRun.id) -ForegroundColor DarkGray
    }
    return
  }

  $asset = Wait-ReleaseAsset -Version $Version -WaitMinutes 5
  Save-IpaFromUrl -Url $asset.browser_download_url -FileName $asset.name | Out-Null
  Write-Host ('CI: https://github.com/{0}/actions/runs/{1}' -f $Repo, $run.Id) -ForegroundColor DarkGray
}

# ---- main ----
$version = Get-AppVersion
Write-Step ("iOS IPA - v{0}" -f $version)
Write-Host ("Root: {0}" -f $Root)

if (Test-IsMacOS) {
  Build-IosLocal -Version $version
} else {
  Assert-Curl
  $targetSha = if ($Sha) { $Sha.Trim() } else { Get-GitSha }
  Write-Host ("Target SHA: {0}" -f $targetSha) -ForegroundColor DarkGray
  Get-IosFromCiOrRelease -Version $version -TargetSha $targetSha
}

Write-Host ''
Write-Host 'Done.' -ForegroundColor Green
exit 0
