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
  [switch]$NoPath,
  [switch]$FixAlias
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
  }
  else {
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

  # Use single-quoted PS strings so CMD variables like %~dp0 and %* are not parsed by PowerShell.
  $shimHeader = '@echo off' + "`r`n" + 'setlocal' + "`r`n"
  $pwshCheck =
  'where pwsh >nul 2>nul' + "`r`n" +
  'if %ERRORLEVEL%==0 (' + "`r`n" +
  '  pwsh -NoProfile -ExecutionPolicy Bypass -File "%~dp0{0}" %*' + "`r`n" +
  ') else (' + "`r`n" +
  '  powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0{0}" %*' + "`r`n" +
  ')' + "`r`n"

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
  }
  else {
    Write-Warn 'Skipping PATH modification (-NoPath).'
  }

  Write-Info 'Installation successful.'

  # PowerShell ships with an alias `gu` -> Get-Unique, which shadows our external `gu.cmd`.
  $existingAlias = $null
  try { $existingAlias = Get-Alias -Name 'gu' -ErrorAction Stop } catch { $existingAlias = $null }
  if ($existingAlias) {
    Write-Warn "PowerShell alias 'gu' is set to '$($existingAlias.Definition)' and will shadow this tool."
    Write-Info "Use 'gu.cmd version' or run: Remove-Item Alias:gu -Force"

    if ($FixAlias) {
      try {
        if (-not (Test-Path -LiteralPath $PROFILE)) {
          $profileDir = Split-Path -Parent $PROFILE
          if (-not (Test-Path -LiteralPath $profileDir)) {
            New-Item -ItemType Directory -Path $profileDir | Out-Null
          }
          New-Item -ItemType File -Path $PROFILE | Out-Null
        }

        $fixLine = "Remove-Item Alias:gu -Force -ErrorAction SilentlyContinue"
        $profileContent = Get-Content -LiteralPath $PROFILE -ErrorAction SilentlyContinue
        if ($profileContent -notcontains $fixLine) {
          Add-Content -LiteralPath $PROFILE -Value $fixLine
          Write-Info "Added alias-fix to $PROFILE (reopen terminal to take effect)."
        }
        else {
          Write-Info "Alias-fix already present in $PROFILE."
        }
      }
      catch {
        Write-Warn "Failed to update PowerShell profile: $($_.Exception.Message)"
      }
    }
    else {
      Write-Info "To persist this fix, re-run installer with -FixAlias, or add this line to your PowerShell profile ($PROFILE):"
      Write-Info "  Remove-Item Alias:gu -Force -ErrorAction SilentlyContinue"
    }
  }

  Write-Info 'Try: gu.cmd version'
}
catch {
  Write-Err $_.Exception.Message
  exit 1
}
