<#
 install.ps1 - Windows PowerShell installer for gu

 Default: per-user install to $env:LOCALAPPDATA\gu\bin and add to User PATH.

 Supports:
 - -Develop (installs from develop branch)
 - Env var GU_BRANCH ("develop"/"main")
 - -InstallDir <path>
 - -NoPath (don't edit PATH)
#>

[CmdletBinding()]
param(
  [switch]$Develop,
  [string]$InstallDir = '',
  [switch]$NoPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoBaseUrl = 'https://raw.githubusercontent.com/hnrobert/gu'

$branch = 'main'
if ($Develop) { $branch = 'develop' }
if ($env:GU_BRANCH) { $branch = $env:GU_BRANCH }

if ([string]::IsNullOrWhiteSpace($InstallDir)) {
  $InstallDir = Join-Path $env:LOCALAPPDATA 'gu\bin'
}

function Write-Info([string]$Message) { Write-Host $Message }
function Write-Warn([string]$Message) { Write-Host $Message -ForegroundColor Yellow }
function Write-Err([string]$Message) { Write-Host $Message -ForegroundColor Red }

function Invoke-Download([string]$Url, [string]$OutFile) {
  $headers = @{ 'Cache-Control' = 'no-cache, no-store, must-revalidate'; 'Pragma' = 'no-cache'; 'Expires' = '0' }
  if ($PSVersionTable.PSVersion.Major -lt 6) {
    Invoke-WebRequest -UseBasicParsing -Headers $headers -Uri $Url -OutFile $OutFile | Out-Null
  } else {
    Invoke-WebRequest -Headers $headers -Uri $Url -OutFile $OutFile | Out-Null
  }
}

try {
  $guUrl = "$repoBaseUrl/$branch/gu.ps1"
  $gutempUrl = "$repoBaseUrl/$branch/gutemp.ps1"

  Write-Info "Installing gu from branch '$branch'"
  Write-Info "Install dir: $InstallDir"

  if (-not (Test-Path -LiteralPath $InstallDir)) {
    New-Item -ItemType Directory -Path $InstallDir | Out-Null
  }

  $tmpGu = Join-Path ([System.IO.Path]::GetTempPath()) ([System.IO.Path]::GetRandomFileName())
  $tmpGutemp = Join-Path ([System.IO.Path]::GetTempPath()) ([System.IO.Path]::GetRandomFileName())

  Write-Info "Downloading $guUrl"
  Invoke-Download -Url $guUrl -OutFile $tmpGu

  Write-Info "Downloading $gutempUrl"
  Invoke-Download -Url $gutempUrl -OutFile $tmpGutemp

  $guPath = Join-Path $InstallDir 'gu.ps1'
  $gutempPath = Join-Path $InstallDir 'gutemp.ps1'

  Move-Item -Force -LiteralPath $tmpGu -Destination $guPath
  Move-Item -Force -LiteralPath $tmpGutemp -Destination $gutempPath

  # Create CMD shims so users can run `gu` / `gutemp` without typing `.ps1`
  $shimGu = Join-Path $InstallDir 'gu.cmd'
  $shimGutemp = Join-Path $InstallDir 'gutemp.cmd'

  $shimHeader = "@echo off`r`nsetlocal`r`n"
  $pwshCheck = "where pwsh >nul 2>nul`r`nif %ERRORLEVEL%==0 (" +
    "`r`n  pwsh -NoProfile -ExecutionPolicy Bypass -File \"%~dp0{0}\" %*`r`n) else (" +
    "`r`n  powershell -NoProfile -ExecutionPolicy Bypass -File \"%~dp0{0}\" %*`r`n)`r`n"

  [System.IO.File]::WriteAllText($shimGu, ($shimHeader + ($pwshCheck -f 'gu.ps1')), (New-Object System.Text.UTF8Encoding($false)))
  [System.IO.File]::WriteAllText($shimGutemp, ($shimHeader + ($pwshCheck -f 'gutemp.ps1')), (New-Object System.Text.UTF8Encoding($false)))

  # Ensure profile storage exists
  $guDir = Join-Path $HOME '.gu'
  $profiles = Join-Path $guDir 'profiles'
  if (-not (Test-Path -LiteralPath $guDir)) { New-Item -ItemType Directory -Path $guDir | Out-Null }
  if (-not (Test-Path -LiteralPath $profiles)) { New-Item -ItemType File -Path $profiles | Out-Null }

  if (-not $NoPath) {
    $userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
    $paths = @()
    if (-not [string]::IsNullOrWhiteSpace($userPath)) {
      $paths = $userPath -split ';'
    }

    $already = $false
    foreach ($p in $paths) {
      if ($p.TrimEnd('\\') -ieq $InstallDir.TrimEnd('\\')) { $already = $true; break }
    }

    if (-not $already) {
      $newPath = if ([string]::IsNullOrWhiteSpace($userPath)) { $InstallDir } else { "$userPath;$InstallDir" }
      [Environment]::SetEnvironmentVariable('Path', $newPath, 'User')
      Write-Info 'Added install dir to User PATH (new terminals will pick it up).'
    }

    # Update current session PATH
    if ($env:Path -notlike "*$InstallDir*") {
      $env:Path = "$InstallDir;$env:Path"
    }
  } else {
    Write-Warn 'Skipping PATH modification (-NoPath).'
  }

  Write-Info 'Installation successful.'
  Write-Info 'Try: gu version'
} catch {
  Write-Err $_.Exception.Message
  exit 1
}
