<#
 gutemp - set Git identity environment for forced-command SSH sessions (alias-only)

 This is the PowerShell port of gutemp.sh.
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$guDir = Join-Path $HOME '.gu'
$configFile = Join-Path $guDir 'profiles'

if ($args.Count -ne 1) {
  Write-Host 'Usage: gutemp <alias>' -ForegroundColor Red
  exit 1
}

$profileAlias = $args[0]

if (-not (Test-Path -LiteralPath $guDir)) {
  New-Item -ItemType Directory -Path $guDir | Out-Null
}

if (-not (Test-Path -LiteralPath $configFile)) {
  Write-Host "Profile file not found at $configFile. Run 'gu add' first." -ForegroundColor Red
  exit 1
}

$lines = Get-Content -LiteralPath $configFile -ErrorAction SilentlyContinue
$match = $lines | Where-Object { $_ -like "$profileAlias|*" } | Select-Object -First 1

if (-not $match) {
  Write-Host "Alias '$profileAlias' not found in $configFile" -ForegroundColor Red
  exit 1
}

$parts = $match -split '\|', 3
if ($parts.Count -lt 3) {
  Write-Host "Alias '$profileAlias' is missing user/email in $configFile" -ForegroundColor Red
  exit 1
}

$user = $parts[1]
$email = $parts[2]

if ([string]::IsNullOrWhiteSpace($user) -or [string]::IsNullOrWhiteSpace($email)) {
  Write-Host "Alias '$profileAlias' is missing user/email in $configFile" -ForegroundColor Red
  exit 1
}

$env:GIT_AUTHOR_NAME = $user
$env:GIT_AUTHOR_EMAIL = $email
$env:GIT_COMMITTER_NAME = $user
$env:GIT_COMMITTER_EMAIL = $email
$env:EMAIL = $email

# If SSH_ORIGINAL_COMMAND is actually the RemoteCommand wrapper (contains gutemp), ignore it.
if ($env:SSH_ORIGINAL_COMMAND -and $env:SSH_ORIGINAL_COMMAND -match 'gutemp') {
  Remove-Item Env:SSH_ORIGINAL_COMMAND -ErrorAction SilentlyContinue
}

if ($env:SSH_ORIGINAL_COMMAND) {
  # Best-effort: execute via a shell. On Windows OpenSSH, this is often empty.
  $cmd = $env:SSH_ORIGINAL_COMMAND
  cmd.exe /c $cmd
  exit $LASTEXITCODE
}

# Default: start an interactive shell
if (Get-Command pwsh -ErrorAction SilentlyContinue) {
  pwsh -NoLogo
} else {
  powershell.exe -NoLogo
}
