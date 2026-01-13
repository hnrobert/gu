<#
 gu (git-user) - PowerShell port

 Notes:
 - Profiles stored at $HOME\.gu\profiles with format: alias|name|email
 - SSH helpers: uses gutemp (installed by install.ps1 as gutemp.ps1 + gutemp.cmd)
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$script:RepoBaseUrl = 'https://raw.githubusercontent.com/hnrobert/gu'
$script:Version = 'v1.2.0'

$script:GuDir = Join-Path $HOME '.gu'
$script:ConfigFile = Join-Path $script:GuDir 'profiles'
$script:RemoteFile = Join-Path $script:GuDir 'remote_hosts'
$script:LastSelectedAlias = ''

function Write-Info([string]$Message) {
  Write-Host $Message
}

function Write-Highlight([string]$Message) {
  Write-Host $Message -ForegroundColor Green
}

function Write-Warn([string]$Message) {
  Write-Host $Message -ForegroundColor Yellow
}

function Write-Err([string]$Message) {
  Write-Host $Message -ForegroundColor Red
}

function Write-AllLinesUtf8NoBom([string]$Path, [string[]]$Lines) {
  $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
  [System.IO.File]::WriteAllLines($Path, $Lines, $utf8NoBom)
}

function Ensure-Storage {
  if (-not (Test-Path -LiteralPath $script:GuDir)) {
    New-Item -ItemType Directory -Path $script:GuDir | Out-Null
  }
  if (-not (Test-Path -LiteralPath $script:ConfigFile)) {
    New-Item -ItemType File -Path $script:ConfigFile | Out-Null
  }
  if (-not (Test-Path -LiteralPath $script:RemoteFile)) {
    New-Item -ItemType File -Path $script:RemoteFile | Out-Null
  }
}

function Default-AliasFromName([string]$InputName) {
  $firstPart = ($InputName -split ' ')[0]
  if ([string]::IsNullOrWhiteSpace($firstPart)) { $firstPart = $InputName }
  $lowered = $firstPart.ToLowerInvariant()
  if ([string]::IsNullOrWhiteSpace($lowered)) { $lowered = 'user' }
  return $lowered
}

function Get-Profiles {
  Ensure-Storage
  $lines = Get-Content -LiteralPath $script:ConfigFile -ErrorAction SilentlyContinue
  $profiles = @()
  foreach ($line in $lines) {
    if ([string]::IsNullOrWhiteSpace($line)) { continue }
    $parts = $line -split '\|', 3
    if ($parts.Count -lt 3) { continue }
    $profiles += [pscustomobject]@{
      Alias = $parts[0]
      Name  = $parts[1]
      Email = $parts[2]
    }
  }
  return $profiles
}

function Get-ProfileByAlias([string]$Alias) {
  if ([string]::IsNullOrWhiteSpace($Alias)) { return $null }
  $profiles = Get-Profiles
  return $profiles | Where-Object { $_.Alias -eq $Alias } | Select-Object -First 1
}

function Require-Git {
  $git = Get-Command git -ErrorAction SilentlyContinue
  if (-not $git) {
    throw 'git not found in PATH. Please install Git for Windows (or ensure git is on PATH).'
  }
}

function Test-InsideGitRepo {
  Require-Git
  try {
    $null = & git rev-parse --is-inside-work-tree 2>$null
    return ($LASTEXITCODE -eq 0)
  }
  catch {
    return $false
  }
}

function Show-Version {
  Write-Info "gu version: $script:Version"
}

function Show-UserInfo {
  Require-Git
  $name = (& git config user.name) 2>$null
  $email = (& git config user.email) 2>$null
  Write-Highlight "Name: $name, Email: $email"
}

function Add-UserProfile([string]$Alias, [string]$Name, [string]$Email) {
  Ensure-Storage
  if ([string]::IsNullOrWhiteSpace($Alias)) { throw 'Alias is required.' }
  if (Get-ProfileByAlias $Alias) {
    Write-Warn "Profile '$Alias' already exists."
    return
  }
  $line = "$Alias|$Name|$Email"
  Add-Content -LiteralPath $script:ConfigFile -Value $line
  Write-Info "Added profile '$Alias' with Name: $Name, Email: $Email"
}

function List-Profiles {
  Ensure-Storage
  $profiles = Get-Profiles
  if ($profiles.Count -eq 0) {
    Write-Info 'No profiles available.'
    return
  }

  Require-Git
  $currentName = (& git config user.name) 2>$null
  $currentEmail = (& git config user.email) 2>$null

  Write-Info 'Available profiles:'
  $i = 1
  foreach ($p in $profiles) {
    $display = "{0}) Alias: {1}, Name: {2}, Email: {3}" -f $i, $p.Alias, $p.Name, $p.Email
    if ($p.Name -eq $currentName -and $p.Email -eq $currentEmail) {
      Write-Highlight "$display (Current)"
    }
    else {
      Write-Info $display
    }
    $i++
  }
}

function Apply-GitIdentity([string]$Scope, [string]$Name, [string]$Email) {
  Require-Git
  if ($Scope -eq 'local' -and -not (Test-InsideGitRepo)) {
    throw 'Local scope requires running inside a git repository. Use --global or run inside a repo.'
  }

  $flag = if ($Scope -eq 'global') { '--global' } else { '--local' }

  & git config $flag user.name $Name | Out-Null
  if ($LASTEXITCODE -ne 0) { throw "Failed to set git user.name ($flag)." }
  & git config $flag user.email $Email | Out-Null
  if ($LASTEXITCODE -ne 0) { throw "Failed to set git user.email ($flag)." }
}

function Set-UserInfo([string[]]$Args) {
  $scope = 'local'
  $userAlias = ''
  $createNew = $false
  $applyGit = $true

  Ensure-Storage

  for ($i = 0; $i -lt $Args.Count; $i++) {
    $a = $Args[$i]
    switch ($a) {
      '--no-apply' { $applyGit = $false; continue }
      '--global' { $scope = 'global'; continue }
      '-g' { $scope = 'global'; continue }
      '--user' {
        if ($i + 1 -ge $Args.Count) { throw '--user requires a value.' }
        $userAlias = $Args[$i + 1]
        $i++
        continue
      }
      '-u' {
        if ($i + 1 -ge $Args.Count) { throw '-u requires a value.' }
        $userAlias = $Args[$i + 1]
        $i++
        continue
      }
      default {
        if ([string]::IsNullOrWhiteSpace($userAlias) -and -not [string]::IsNullOrWhiteSpace($a)) {
          $userAlias = $a
        }
      }
    }
  }

  if ([string]::IsNullOrWhiteSpace($userAlias)) {
    $profiles = Get-Profiles
    if ($profiles.Count -gt 0) {
      Write-Info 'Available profiles:'
      for ($j = 0; $j -lt $profiles.Count; $j++) {
        $p = $profiles[$j]
        Write-Info ("{0}) Alias: {1}, Name: {2}, Email: {3}" -f ($j + 1), $p.Alias, $p.Name, $p.Email)
      }
      $addOption = $profiles.Count + 1
      Write-Info ("{0}) Add another profile" -f $addOption)

      $selection = Read-Host 'Select number or enter alias'
      if ([string]::IsNullOrWhiteSpace($selection)) {
        throw 'No selection made.'
      }

      $num = 0
      if ([int]::TryParse($selection, [ref]$num)) {
        if ($num -ge 1 -and $num -lt $addOption) {
          $userAlias = $profiles[$num - 1].Alias
        }
        elseif ($num -eq $addOption) {
          $createNew = $true
        }
        else {
          throw 'Invalid selection.'
        }
      }
      else {
        $userAlias = $selection
      }
    }
    else {
      $createNew = $true
    }
  }

  if (-not $createNew -and -not [string]::IsNullOrWhiteSpace($userAlias)) {
    $profile = Get-ProfileByAlias $userAlias
    if ($profile) {
      if ($applyGit) {
        Apply-GitIdentity -Scope $scope -Name $profile.Name -Email $profile.Email
        Write-Info "Set to profile: Alias: $($profile.Alias), Name: $($profile.Name), Email: $($profile.Email) (Scope: $scope)"
      }
      $script:LastSelectedAlias = $profile.Alias
      return
    }

    Write-Warn "Profile '$userAlias' not found."
    $createChoice = Read-Host "Create a new profile named '$userAlias'? [y/N]"
    if ($createChoice -notmatch '^[Yy]$') {
      throw 'No changes made.'
    }
    $createNew = $true
    $alias = $userAlias
  }

  if ($createNew) {
    $name = Read-Host 'Enter git user name'
    $email = Read-Host 'Enter email'
    $defaultAlias = Default-AliasFromName $name
    $alias = Read-Host "Enter alias (default: $defaultAlias)"
    if ([string]::IsNullOrWhiteSpace($alias)) { $alias = $defaultAlias }

    if ($applyGit) {
      Apply-GitIdentity -Scope $scope -Name $name -Email $email
    }

    Write-Info "User information set to Name: $name, Email: $email (Scope: $scope)"
    Add-UserProfile -Alias $alias -Name $name -Email $email
    $script:LastSelectedAlias = $alias
  }
}

function Add-ProfileInteractive([string[]]$Args) {
  $userAlias = ''
  for ($i = 0; $i -lt $Args.Count; $i++) {
    $a = $Args[$i]
    switch ($a) {
      '--user' {
        if ($i + 1 -ge $Args.Count) { throw '--user requires a value.' }
        $userAlias = $Args[$i + 1]
        $i++
        continue
      }
      '-u' {
        if ($i + 1 -ge $Args.Count) { throw '-u requires a value.' }
        $userAlias = $Args[$i + 1]
        $i++
        continue
      }
      default {
        if ([string]::IsNullOrWhiteSpace($userAlias)) {
          $userAlias = $a
        }
      }
    }
  }

  Ensure-Storage

  if (-not [string]::IsNullOrWhiteSpace($userAlias)) {
    if (Get-ProfileByAlias $userAlias) {
      Write-Warn "Profile '$userAlias' already exists."
      return
    }
    $name = Read-Host 'Enter git user name'
    $email = Read-Host 'Enter email'
    $alias = $userAlias
  }
  else {
    $name = Read-Host 'Enter git user name'
    $email = Read-Host 'Enter email'
    $alias = Read-Host 'Enter alias'
  }

  Add-UserProfile -Alias $alias -Name $name -Email $email
}

function Delete-UserProfile([string[]]$Args) {
  $userAlias = ''
  Ensure-Storage

  $profiles = Get-Profiles
  if ($profiles.Count -eq 0) {
    Write-Info 'No profiles available to delete.'
    return
  }

  for ($i = 0; $i -lt $Args.Count; $i++) {
    $a = $Args[$i]
    switch ($a) {
      '--user' {
        if ($i + 1 -ge $Args.Count) { throw '--user requires a value.' }
        $userAlias = $Args[$i + 1]
        $i++
        continue
      }
      '-u' {
        if ($i + 1 -ge $Args.Count) { throw '-u requires a value.' }
        $userAlias = $Args[$i + 1]
        $i++
        continue
      }
      default {
        if ([string]::IsNullOrWhiteSpace($userAlias)) { $userAlias = $a }
      }
    }
  }

  if (-not [string]::IsNullOrWhiteSpace($userAlias)) {
    $lines = Get-Content -LiteralPath $script:ConfigFile
    $newLines = $lines | Where-Object { $_ -notmatch "^$([Regex]::Escape($userAlias))\|" }
    if ($newLines.Count -eq $lines.Count) {
      Write-Warn "Profile '$userAlias' not found."
      return
    }
    Write-AllLinesUtf8NoBom -Path $script:ConfigFile -Lines $newLines
    Write-Info "Profile '$userAlias' deleted."
    return
  }

  List-Profiles
  $profiles = Get-Profiles
  if ($profiles.Count -eq 0) { return }

  $choice = Read-Host 'Enter the number of the profile to delete'
  $num = 0
  if (-not [int]::TryParse($choice, [ref]$num)) {
    throw 'Invalid selection.'
  }
  if ($num -lt 1 -or $num -gt $profiles.Count) {
    throw 'Invalid selection.'
  }

  $aliasToDelete = $profiles[$num - 1].Alias
  $lines = Get-Content -LiteralPath $script:ConfigFile
  $newLines = $lines | Where-Object { $_ -notmatch "^$([Regex]::Escape($aliasToDelete))\|" }
  Write-AllLinesUtf8NoBom -Path $script:ConfigFile -Lines $newLines
  Write-Info 'Profile deleted.'
}

function Update-UserInfo([string[]]$Args) {
  $userAlias = ''
  Ensure-Storage

  for ($i = 0; $i -lt $Args.Count; $i++) {
    $a = $Args[$i]
    switch ($a) {
      '--user' {
        if ($i + 1 -ge $Args.Count) { throw '--user requires a value.' }
        $userAlias = $Args[$i + 1]
        $i++
        continue
      }
      '-u' {
        if ($i + 1 -ge $Args.Count) { throw '-u requires a value.' }
        $userAlias = $Args[$i + 1]
        $i++
        continue
      }
      default {
        if ([string]::IsNullOrWhiteSpace($userAlias)) { $userAlias = $a }
      }
    }
  }

  if ([string]::IsNullOrWhiteSpace($userAlias)) {
    List-Profiles
    $profiles = Get-Profiles
    if ($profiles.Count -eq 0) { throw 'No profiles available.' }

    $userChoice = Read-Host 'Enter alias or number to update'
    if ([string]::IsNullOrWhiteSpace($userChoice)) { throw 'No alias provided.' }

    $num = 0
    if ([int]::TryParse($userChoice, [ref]$num) -and $num -ge 1 -and $num -le $profiles.Count) {
      $userAlias = $profiles[$num - 1].Alias
    }
    else {
      $userAlias = $userChoice
    }
  }

  $profile = Get-ProfileByAlias $userAlias
  if ($profile) {
    $newAlias = Read-Host "Enter alias [$($profile.Alias)]"
    if ([string]::IsNullOrWhiteSpace($newAlias)) { $newAlias = $profile.Alias }

    $newName = Read-Host "Enter git user name [$($profile.Name)]"
    if ([string]::IsNullOrWhiteSpace($newName)) { $newName = $profile.Name }

    $newEmail = Read-Host "Enter email [$($profile.Email)]"
    if ([string]::IsNullOrWhiteSpace($newEmail)) { $newEmail = $profile.Email }

    if ($newAlias -ne $profile.Alias -and (Get-ProfileByAlias $newAlias)) {
      throw "Alias '$newAlias' already exists. No changes made."
    }

    $lines = Get-Content -LiteralPath $script:ConfigFile
    $out = @()
    foreach ($line in $lines) {
      if ($line -match "^$([Regex]::Escape($profile.Alias))\|") {
        $out += "$newAlias|$newName|$newEmail"
      }
      else {
        $out += $line
      }
    }

    Write-AllLinesUtf8NoBom -Path $script:ConfigFile -Lines $out
    Write-Info "Profile '$($profile.Alias)' updated to Alias: $newAlias, Name: $newName, Email: $newEmail"
    return
  }

  Write-Warn "Profile '$userAlias' not found."
  $createChoice = Read-Host "Create a new profile named '$userAlias'? [y/N]"
  if ($createChoice -notmatch '^[Yy]$') {
    throw 'No changes made.'
  }
  $name = Read-Host 'Enter git user name'
  $email = Read-Host 'Enter email'
  Add-UserProfile -Alias $userAlias -Name $name -Email $email
}

function Get-AuthorizedKeysPath {
  $sshDir = Join-Path $HOME '.ssh'
  if (-not (Test-Path -LiteralPath $sshDir)) {
    New-Item -ItemType Directory -Path $sshDir | Out-Null
  }
  return (Join-Path $sshDir 'authorized_keys')
}

function Parse-AuthorizedKeyLine([string]$Line) {
  $result = [ordered]@{
    Options       = ''
    KeyType       = ''
    KeyBody       = ''
    Comment       = ''
    AssignedAlias = ''
  }

  $tokens = $Line -split ' '
  $keyIdx = -1
  for ($i = 0; $i -lt $tokens.Count; $i++) {
    if ($tokens[$i] -match '^(ssh-|ecdsa-|sk-).+') {
      $keyIdx = $i
      break
    }
  }
  if ($keyIdx -lt 0) { return $null }

  if ($keyIdx -gt 0) {
    $result.Options = ($tokens[0..($keyIdx - 1)] -join ' ').TrimEnd()
  }
  $result.KeyType = $tokens[$keyIdx]
  if ($keyIdx + 1 -ge $tokens.Count) { return $null }
  $result.KeyBody = $tokens[$keyIdx + 1]
  if ($keyIdx + 2 -lt $tokens.Count) {
    $result.Comment = ($tokens[($keyIdx + 2)..($tokens.Count - 1)] -join ' ')
  }

  $m = [regex]::Match($Line, 'command="([^"]*)"')
  if ($m.Success) {
    $cmdValue = $m.Groups[1].Value
    $m2 = [regex]::Match($cmdValue, '(^|\s)[^\s]*gutemp[^\s]*\s+([^\s]+)(\s|$)')
    if ($m2.Success) {
      $result.AssignedAlias = $m2.Groups[2].Value
    }
  }

  if ([string]::IsNullOrWhiteSpace($result.KeyType) -or [string]::IsNullOrWhiteSpace($result.KeyBody)) {
    return $null
  }

  return [pscustomobject]$result
}

function Clean-AuthorizedKeysOptionsRemoveCommand([string]$Options) {
  if ([string]::IsNullOrWhiteSpace($Options)) { return '' }
  $clean = $Options -replace '(^|,)command="[^"]*"(,|$)', '$1'
  $clean = $clean -replace ',,', ','
  $clean = $clean.Trim(',')
  $clean = $clean.Trim()
  return $clean
}

function Resolve-GutempForForcedCommand {
  $cmd = $null

  foreach ($name in @('gutemp.cmd', 'gutemp.bat', 'gutemp.exe', 'gutemp')) {
    $c = Get-Command $name -ErrorAction SilentlyContinue
    if ($c) { $cmd = $c.Source; break }
  }

  if (-not $cmd) {
    $candidate = Join-Path $PSScriptRoot 'gutemp.cmd'
    if (Test-Path -LiteralPath $candidate) { $cmd = $candidate }
  }
  if (-not $cmd) {
    throw 'gutemp not found. Please install using install.ps1 (it creates gutemp.cmd shim).'
  }
  return $cmd
}

function Config-AuthKey([string]$Alias) {
  $aliasProvided = -not [string]::IsNullOrWhiteSpace($Alias)

  Ensure-Storage
  $authKeys = Get-AuthorizedKeysPath
  if (-not (Test-Path -LiteralPath $authKeys)) {
    New-Item -ItemType File -Path $authKeys | Out-Null
  }

  $lines = Get-Content -LiteralPath $authKeys -ErrorAction SilentlyContinue
  $selectable = @()
  $display = @()

  $idx = 1
  foreach ($line in $lines) {
    if ([string]::IsNullOrWhiteSpace($line) -or $line.TrimStart().StartsWith('#')) {
      continue
    }

    $parsed = Parse-AuthorizedKeyLine $line
    if (-not $parsed) { continue }

    $prefix = if ($parsed.KeyBody.Length -ge 5) { $parsed.KeyBody.Substring(0, 5) } else { $parsed.KeyBody }
    $comment = if ([string]::IsNullOrWhiteSpace($parsed.Comment)) { '<no-comment>' } else { $parsed.Comment }

    $lineText = "{0}) {1} {2}... {3}" -f $idx, $parsed.KeyType, $prefix, $comment
    if (-not [string]::IsNullOrWhiteSpace($parsed.AssignedAlias)) {
      $lineText += " -> $($parsed.AssignedAlias)"
    }

    Write-Info $lineText
    $selectable += $line
    $idx++
  }

  if ($selectable.Count -eq 0) {
    throw "No keys found in $authKeys."
  }

  $choice = Read-Host 'Select key number to bind'
  $num = 0
  if (-not [int]::TryParse($choice, [ref]$num)) { throw 'Invalid selection.' }
  if ($num -lt 1 -or $num -gt $selectable.Count) { throw 'Invalid selection.' }

  $selectedLine = $selectable[$num - 1]
  $parsed = Parse-AuthorizedKeyLine $selectedLine
  if (-not $parsed) { throw 'Failed to parse the selected key.' }

  $hadCommand = $false
  $existingCommand = ''
  if (-not [string]::IsNullOrWhiteSpace($parsed.Options) -and $parsed.Options -match 'command="([^"]*)"') {
    $hadCommand = $true
    $existingCommand = $Matches[1]
  }

  if ($hadCommand -and -not $aliasProvided) {
    Write-Info "Selected key already has command=\"$existingCommand\"."
    $commandChoice = Read-Host 'Delete existing command or overwrite with gutemp alias? [d/o]'

    if ($commandChoice -match '^[Dd]$') {
      $options = Clean-AuthorizedKeysOptionsRemoveCommand $parsed.Options

      $cleanedLine = ''
      if (-not [string]::IsNullOrWhiteSpace($options)) {
        $cleanedLine = "$options $($parsed.KeyType) $($parsed.KeyBody)"
      }
      else {
        $cleanedLine = "$($parsed.KeyType) $($parsed.KeyBody)"
      }
      if (-not [string]::IsNullOrWhiteSpace($parsed.Comment)) {
        $cleanedLine = "$cleanedLine $($parsed.Comment)"
      }

      $outLines = @()
      $replaced = $false
      foreach ($l in $lines) {
        if (-not $replaced -and $l -eq $selectedLine) {
          $outLines += $cleanedLine
          $replaced = $true
        }
        else {
          $outLines += $l
        }
      }

      Write-AllLinesUtf8NoBom -Path $authKeys -Lines $outLines
      Write-Info 'Removed existing command= from selected key; no alias binding applied.'
      return
    }

    if ($commandChoice -notmatch '^[Oo]$') {
      throw 'No changes made.'
    }
  }

  if ([string]::IsNullOrWhiteSpace($Alias)) {
    Write-Info 'No alias provided. Please choose or create one.'
    Set-UserInfo @('--no-apply')
    if ([string]::IsNullOrWhiteSpace($script:LastSelectedAlias)) {
      throw 'Alias selection failed.'
    }
    $Alias = $script:LastSelectedAlias
  }

  if (-not (Get-ProfileByAlias $Alias)) {
    throw "Alias '$Alias' not found in $script:ConfigFile. Run 'gu set -u $Alias' to create it first."
  }

  $gutempCmd = Resolve-GutempForForcedCommand
  $commandValue = "command=\"$gutempCmd $Alias\""

  $options2 = Clean-AuthorizedKeysOptionsRemoveCommand $parsed.Options

  $newLine = ''
  if (-not [string]::IsNullOrWhiteSpace($options2)) {
    $newLine = "$commandValue,$options2 $($parsed.KeyType) $($parsed.KeyBody)"
  }
  else {
    $newLine = "$commandValue $($parsed.KeyType) $($parsed.KeyBody)"
  }
  if (-not [string]::IsNullOrWhiteSpace($parsed.Comment)) {
    $newLine = "$newLine $($parsed.Comment)"
  }

  $outLines = @()
  $replaced = $false
  foreach ($l in $lines) {
    if (-not $replaced -and $l -eq $selectedLine) {
      $outLines += $newLine
      $replaced = $true
    }
    else {
      $outLines += $l
    }
  }

  Write-AllLinesUtf8NoBom -Path $authKeys -Lines $outLines
  Write-Info "Bound alias '$Alias' to selected key via command='$gutempCmd $Alias'."
}

function Parse-RemoteAliasFromRemoteCommand([string]$RemoteCommandLine) {
  $words = $RemoteCommandLine -split '\s+'
  $last = ''
  for ($i = 0; $i -lt $words.Count; $i++) {
    $w = $words[$i]
    if ($w -eq 'gutemp' -or $w.EndsWith('/gutemp') -or $w.EndsWith('\\gutemp') -or $w -like '*gutemp*') {
      if ($i + 1 -lt $words.Count) {
        $nxt = $words[$i + 1]
        $nxt = $nxt -replace ';.*$', ''
        if (-not [string]::IsNullOrWhiteSpace($nxt)) { $last = $nxt }
      }
    }
  }
  return $last
}

function Config-RemoteHost([string]$RemoteAlias, [string]$SshConfigPath) {
  Ensure-Storage

  if ([string]::IsNullOrWhiteSpace($SshConfigPath)) {
    $SshConfigPath = Join-Path (Join-Path $HOME '.ssh') 'config'
  }

  if (-not (Test-Path -LiteralPath $SshConfigPath)) {
    throw "SSH config not found at $SshConfigPath."
  }

  $rawLines = Get-Content -LiteralPath $SshConfigPath

  $hosts = @()
  $hostAliases = @()

  $currentHosts = @()
  $currentAlias = ''

  function Finish-HostBlock {
    if ($currentHosts.Count -gt 0) {
      foreach ($h in $currentHosts) {
        $hosts += $h
        $hostAliases += $currentAlias
      }
    }
    $script:__currentHosts = @()
  }

  # Manual state (avoid nested function capture quirks in PS 5.1)
  $currentHosts = @()
  $currentAlias = ''

  foreach ($line in $rawLines) {
    $trim = $line.Trim()
    if ([string]::IsNullOrWhiteSpace($trim) -or $trim.StartsWith('#')) { continue }

    $mHost = [regex]::Match($line, '^\s*[Hh]ost\s+(.+)$')
    if ($mHost.Success) {
      if ($currentHosts.Count -gt 0) {
        foreach ($h in $currentHosts) { $hosts += $h; $hostAliases += $currentAlias }
      }
      $currentHosts = @()
      $currentAlias = ''

      $hostList = $mHost.Groups[1].Value
      $tokens = $hostList -split '\s+'
      foreach ($h in $tokens) {
        if ($h -like '*`**' -or $h -like '*?*' -or $h.StartsWith('!')) { continue }
        if ($h -like '*' * ) {
          # keep same behavior as bash: skip globs
          continue
        }
        if ($h.Contains('*') -or $h.Contains('?')) { continue }
        $currentHosts += $h
      }
      continue
    }

    if ($currentHosts.Count -gt 0) {
      $mRc = [regex]::Match($line, '^\s*RemoteCommand\s+(.+)$')
      if ($mRc.Success) {
        $rcVal = $mRc.Groups[1].Value
        $currentAlias = Parse-RemoteAliasFromRemoteCommand $rcVal
      }
    }
  }

  if ($currentHosts.Count -gt 0) {
    foreach ($h in $currentHosts) { $hosts += $h; $hostAliases += $currentAlias }
  }

  if ($hosts.Count -eq 0) {
    throw "No Host entries found in $SshConfigPath."
  }

  Write-Info 'Available SSH hosts:'
  for ($i = 0; $i -lt $hosts.Count; $i++) {
    $h = $hosts[$i]
    $ha = $hostAliases[$i]
    if (-not [string]::IsNullOrWhiteSpace($ha)) {
      Write-Info ("{0}) {1} -> {2}" -f ($i + 1), $h, $ha)
    }
    else {
      Write-Info ("{0}) {1}" -f ($i + 1), $h)
    }
  }

  $choice = Read-Host 'Select host number to bind'
  $num = 0
  if (-not [int]::TryParse($choice, [ref]$num)) { throw 'Invalid selection.' }
  if ($num -lt 1 -or $num -gt $hosts.Count) { throw 'Invalid selection.' }

  $selectedHost = $hosts[$num - 1]

  # Detect existing RemoteCommand inside target Host block
  $hadRemote = $false
  $existingRemote = ''
  $existingAlias = ''
  $inBlock = $false

  foreach ($line in $rawLines) {
    $mHost = [regex]::Match($line, '^\s*[Hh]ost\s+(.+)$')
    if ($mHost.Success) {
      $inBlock = $false
      $tokens = ($mHost.Groups[1].Value -split '\s+')
      foreach ($h in $tokens) {
        if ($h -eq $selectedHost) { $inBlock = $true; break }
      }
      continue
    }

    if ($inBlock) {
      $mRc = [regex]::Match($line, '^\s*RemoteCommand\s+(.+)$')
      if ($mRc.Success) {
        $hadRemote = $true
        $existingRemote = $mRc.Groups[1].Value
        $existingAlias = Parse-RemoteAliasFromRemoteCommand $existingRemote
        break
      }
    }
  }

  $action = 'overwrite'
  if ($hadRemote) {
    Write-Info "Selected host already has RemoteCommand: $existingRemote"
    $rcChoice = Read-Host 'Delete existing RemoteCommand or overwrite with gutemp alias? [d/o]'
    if ($rcChoice -match '^[Dd]$') {
      $action = 'delete'
    }
    elseif ($rcChoice -match '^[Oo]$') {
      $action = 'overwrite'
    }
    else {
      throw 'No changes made.'
    }
  }

  if ($hadRemote -and $action -eq 'delete') {
    if ([string]::IsNullOrWhiteSpace($RemoteAlias)) {
      $RemoteAlias = $existingAlias
    }
  }

  if ($action -eq 'overwrite' -and [string]::IsNullOrWhiteSpace($RemoteAlias)) {
    $RemoteAlias = Read-Host "Enter alias to map to host '$selectedHost'"
    if ([string]::IsNullOrWhiteSpace($RemoteAlias)) { throw 'Alias is required.' }
  }

  $remoteCommandValue = "if command -v gutemp >/dev/null 2>&1; then env -u SSH_ORIGINAL_COMMAND gutemp $RemoteAlias; else echo 'gutemp not found on remote; skipping' >&2; fi; exec \$SHELL -l"

  # Rewrite ssh config
  $out = @()
  $inTarget = $false
  $inserted = $false

  foreach ($line in $rawLines) {
    $mHost = [regex]::Match($line, '^\s*[Hh]ost\s+(.+)$')
    if ($mHost.Success) {
      if ($inTarget -and -not $inserted -and $action -eq 'overwrite') {
        $out += "  RemoteCommand $remoteCommandValue"
        $out += '  RequestTTY yes'
        $out += ''
        $inserted = $true
      }

      $inTarget = $false
      $tokens = ($mHost.Groups[1].Value -split '\s+')
      foreach ($h in $tokens) {
        if ($h -eq $selectedHost) { $inTarget = $true; break }
      }

      $out += $line
      continue
    }

    if ($inTarget) {
      if ($line -match '^\s*RemoteCommand\s+') { continue }
      if ($line -match '^\s*RequestTTY\s+') { continue }
      if ($action -eq 'overwrite' -and [string]::IsNullOrWhiteSpace($line)) { continue }
    }

    $out += $line
  }

  if ($inTarget -and -not $inserted -and $action -eq 'overwrite') {
    $out += "  RemoteCommand $remoteCommandValue"
    $out += '  RequestTTY yes'
    $out += ''
  }

  Write-AllLinesUtf8NoBom -Path $SshConfigPath -Lines $out

  # Update remote_hosts mapping file (best-effort)
  $remoteLines = @()
  if (Test-Path -LiteralPath $script:RemoteFile) {
    $remoteLines = Get-Content -LiteralPath $script:RemoteFile -ErrorAction SilentlyContinue
  }
  $filtered = @()
  foreach ($l in $remoteLines) {
    if ([string]::IsNullOrWhiteSpace($l)) { continue }
    $parts = $l -split '\|', 3
    if ($parts.Count -lt 3) { continue }
    if ($parts[0] -eq $RemoteAlias) { continue }
    if ($parts[1] -eq $selectedHost) { continue }
    $filtered += $l
  }

  if ($action -eq 'overwrite') {
    $filtered += "$RemoteAlias|$selectedHost|$SshConfigPath"
    Write-AllLinesUtf8NoBom -Path $script:RemoteFile -Lines $filtered
    Write-Info "Mapped remote alias '$RemoteAlias' to Host '$selectedHost' (config: $SshConfigPath)."
  }
  else {
    Write-AllLinesUtf8NoBom -Path $script:RemoteFile -Lines $filtered
    Write-Info "Removed existing RemoteCommand from Host '$selectedHost'; no new mapping stored."
  }
}

function Config-Command([string[]]$Args) {
  $mode = ''
  $alias = ''
  $sshConfigPath = ''

  for ($i = 0; $i -lt $Args.Count; $i++) {
    $a = $Args[$i]
    switch ($a) {
      '-k' { $mode = 'authkey'; continue }
      '--auth-key' { $mode = 'authkey'; continue }
      '-r' {
        $mode = 'remotehost'
        if ($i + 1 -lt $Args.Count -and -not $Args[$i + 1].StartsWith('-')) {
          $alias = $Args[$i + 1]
          $i++
        }
        continue
      }
      '--remote-host' {
        $mode = 'remotehost'
        if ($i + 1 -lt $Args.Count -and -not $Args[$i + 1].StartsWith('-')) {
          $alias = $Args[$i + 1]
          $i++
        }
        continue
      }
      '-c' {
        if ($i + 1 -ge $Args.Count) { throw '-c requires a value.' }
        $sshConfigPath = $Args[$i + 1]
        $i++
        continue
      }
      '--config' {
        if ($i + 1 -ge $Args.Count) { throw '--config requires a value.' }
        $sshConfigPath = $Args[$i + 1]
        $i++
        continue
      }
      '--user' {
        if ($i + 1 -ge $Args.Count) { throw '--user requires a value.' }
        $alias = $Args[$i + 1]
        $i++
        continue
      }
      '-u' {
        if ($i + 1 -ge $Args.Count) { throw '-u requires a value.' }
        $alias = $Args[$i + 1]
        $i++
        continue
      }
      default {
        if ([string]::IsNullOrWhiteSpace($alias)) { $alias = $a }
      }
    }
  }

  switch ($mode) {
    'authkey' { Config-AuthKey -Alias $alias; return }
    'remotehost' { Config-RemoteHost -RemoteAlias $alias -SshConfigPath $sshConfigPath; return }
    default {
      throw 'Unsupported config command. Use: gu config -k [ALIAS] or gu config -r [ALIAS] [-c SSH_CONFIG]'
    }
  }
}

function Invoke-Download([string]$Url, [string]$OutFile) {
  $headers = @{ 'Cache-Control' = 'no-cache, no-store, must-revalidate'; 'Pragma' = 'no-cache'; 'Expires' = '0' }
  if ($PSVersionTable.PSVersion.Major -lt 6) {
    Invoke-WebRequest -UseBasicParsing -Headers $headers -Uri $Url -OutFile $OutFile | Out-Null
  }
  else {
    Invoke-WebRequest -Headers $headers -Uri $Url -OutFile $OutFile | Out-Null
  }
}

function Upgrade-Gu([string[]]$Args) {
  $targetBranch = 'main'
  foreach ($a in $Args) {
    if ($a -eq '-d' -or $a -eq '--develop') { $targetBranch = 'develop' }
  }

  $scriptUrl = "$script:RepoBaseUrl/$targetBranch/gu.ps1"
  $gutempUrl = "$script:RepoBaseUrl/$targetBranch/gutemp.ps1"

  $tmpGu = [System.IO.Path]::GetTempFileName()
  $tmpGutemp = [System.IO.Path]::GetTempFileName()

  Write-Info "Downloading latest gu from $scriptUrl ..."
  Invoke-Download -Url $scriptUrl -OutFile $tmpGu

  Write-Info "Downloading latest gutemp from $gutempUrl ..."
  Invoke-Download -Url $gutempUrl -OutFile $tmpGutemp

  $targetPath = $MyInvocation.MyCommand.Path
  if ([string]::IsNullOrWhiteSpace($targetPath) -or -not (Test-Path -LiteralPath $targetPath)) {
    throw 'Cannot determine installed gu.ps1 path for upgrade.'
  }

  $targetDir = Split-Path -Parent $targetPath
  $targetGutemp = Join-Path $targetDir 'gutemp.ps1'

  Move-Item -Force -LiteralPath $tmpGu -Destination $targetPath
  Move-Item -Force -LiteralPath $tmpGutemp -Destination $targetGutemp

  Write-Info 'Update successful.'
  Show-Version
}

function Show-Help {
  Write-Host 'Usage: gu [COMMAND] [OPTIONS] [ALIAS]'
  Write-Host ''
  Write-Host 'A tool to manage Git user and email information.'
  Write-Host ''
  Write-Host 'Commands:'
  Write-Host '  show                                          Show the current user info.'
  Write-Host '  list                                          List all available user profiles with the current one highlighted.'
  Write-Host '  add [-u|--user ALIAS | ALIAS]                 Add a new user profile with a unique alias.'
  Write-Host '  set [-g|--global] [-u|--user ALIAS | ALIAS]   Switch to an existing profile and apply it. If missing, optionally create.'
  Write-Host '  delete [-u|--user ALIAS | ALIAS]              Delete an existing user profile.'
  Write-Host '  update [-u|--user ALIAS | ALIAS]              Update profile alias/name/email in the config file (create on request).'
  Write-Host '  config -k|--auth-key [ALIAS]                  Bind an SSH authorized_key entry to a gu alias via forced command.'
  Write-Host '  config -r|--remote-host [ALIAS] [-c PATH]     Map an SSH config Host to a gu remote alias (optional SSH config path).'
  Write-Host '  upgrade [-d|--develop]                        Download and install the latest version of gu (default main, -d uses develop).'
  Write-Host '  help | -h | --help                            Show this help message and exit.'
  Write-Host '  version | -v | --version                      Show the current tool version.'
  Write-Host ''
  Write-Host 'Examples:'
  Write-Host '  gu list'
  Write-Host '  gu show'
  Write-Host '  gu add work'
  Write-Host '  gu set -g'
  Write-Host '  gu set -u hnrobert'
  Write-Host '  gu delete prev'
  Write-Host '  gu update -u workuser'
  Write-Host '  gu config -k workuser'
  Write-Host '  gu config -r myremote -c ~/.ssh/config'
  Write-Host '  gu upgrade -d'
}

# Main
try {
  $command = if ($args.Count -gt 0) { $args[0] } else { '' }

  switch ($command) {
    'version' { Show-Version; break }
    '--version' { Show-Version; break }
    '-v' { Show-Version; break }

    'help' { Show-Help; break }
    '--help' { Show-Help; break }
    '-h' { Show-Help; break }

    'show' { Show-UserInfo; break }
    'list' { List-Profiles; break }

    'add' { Add-ProfileInteractive -Args $args[1..($args.Count - 1)]; break }
    'set' { Set-UserInfo -Args $args[1..($args.Count - 1)]; break }
    'delete' { Delete-UserProfile -Args $args[1..($args.Count - 1)]; break }
    'update' { Update-UserInfo -Args $args[1..($args.Count - 1)]; break }

    'config' { Config-Command -Args $args[1..($args.Count - 1)]; break }

    'upgrade' { Upgrade-Gu -Args $args[1..($args.Count - 1)]; break }

    default {
      Write-Err 'Invalid command. Showing help:'
      Show-Help
      exit 1
    }
  }
}
catch {
  Write-Err $_.Exception.Message
  exit 1
}
