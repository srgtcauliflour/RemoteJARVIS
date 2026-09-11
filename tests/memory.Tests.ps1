[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$ProjectRoot = [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$ScriptUnderTest = Join-Path $ProjectRoot 'scripts\Initialize-Memory.ps1'
$ScratchParent = [IO.Path]::GetFullPath((Join-Path $ProjectRoot '.tmp'))
$ScratchRoot = [IO.Path]::GetFullPath((Join-Path $ScratchParent "memory-tests-$([guid]::NewGuid().ToString('N'))"))
$Utf8NoBom = [Text.UTF8Encoding]::new($false)
$Passed = 0

function Assert-True {
  param(
    [Parameter(Mandatory)][bool]$Condition,
    [Parameter(Mandatory)][string]$Message
  )
  if (-not $Condition) { throw "Assertion failed: $Message" }
}

function Assert-Equal {
  param(
    [AllowNull()]$Expected,
    [AllowNull()]$Actual,
    [Parameter(Mandatory)][string]$Message
  )
  if ($Expected -cne $Actual) {
    throw "Assertion failed: $Message`nExpected: $Expected`nActual:   $Actual"
  }
}

function Invoke-Test {
  param(
    [Parameter(Mandatory)][string]$Name,
    [Parameter(Mandatory)][scriptblock]$Test
  )
  & $Test
  $script:Passed++
  Write-Host "[pass] $Name"
}

function Assert-ContainedScratchPath {
  param([Parameter(Mandatory)][string]$LiteralPath)
  $fullPath = [IO.Path]::GetFullPath($LiteralPath)
  $prefix = $ScratchParent.TrimEnd([IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar) + [IO.Path]::DirectorySeparatorChar
  Assert-True -Condition ($fullPath.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase)) -Message "cleanup path must remain below workspace scratch root: $fullPath"
  Assert-True -Condition ($fullPath -cne $ScratchParent) -Message 'cleanup path must not be the scratch parent itself'
  return $fullPath
}

function Get-TreeState {
  param([Parameter(Mandatory)][string]$LiteralPath)
  if (-not (Test-Path -LiteralPath $LiteralPath)) { return '<absent>' }
  $root = [IO.Path]::GetFullPath($LiteralPath)
  $items = Get-ChildItem -LiteralPath $root -Force -Recurse | Sort-Object FullName
  $state = foreach ($item in $items) {
    $relative = $item.FullName.Substring($root.Length).TrimStart('\', '/')
    if ($item.PSIsContainer) {
      "D|$relative"
    } else {
      $hash = (Get-FileHash -LiteralPath $item.FullName -Algorithm SHA256).Hash
      "F|$relative|$hash"
    }
  }
  return ($state -join "`n")
}

function New-TestProject {
  param([Parameter(Mandatory)][string]$Name)
  $caseRoot = [IO.Path]::GetFullPath((Join-Path $ScratchRoot $Name))
  Assert-ContainedScratchPath -LiteralPath $caseRoot | Out-Null

  $fixtureSource = Join-Path $caseRoot 'upstream\source\jaredrhod-ai-memory-vault-659bba9'
  $fixtureTemplates = Join-Path $fixtureSource 'templates'
  $fixtureAgent = Join-Path $caseRoot 'runtime\agent'
  New-Item -ItemType Directory -Path $fixtureTemplates, $fixtureAgent -Force | Out-Null

  $realSource = Join-Path $ProjectRoot 'upstream\source\jaredrhod-ai-memory-vault-659bba9'
  Copy-Item -LiteralPath (Join-Path $realSource 'LICENSE') -Destination (Join-Path $fixtureSource 'LICENSE')
  foreach ($templateName in @('CLAUDE.md', 'DAILY-NOTE.md', 'MEMORY.md', 'VAULT-INDEX.md')) {
    Copy-Item -LiteralPath (Join-Path $realSource "templates\$templateName") -Destination (Join-Path $fixtureTemplates $templateName)
  }

  $vaultRoot = [IO.Path]::GetFullPath((Join-Path $caseRoot 'runtime\memory-vault'))
  $minimalBoot = @(
    '# RemoteJARVIS',
    '',
    "You are RemoteJARVIS. Your memory path is $vaultRoot (the vault is new and memory is not initialized).",
    'Respect project permissions and ask before actions that change files, run commands, or affect external systems. Do not bypass permissions.'
  ) -join [Environment]::NewLine
  $minimalBoot += [Environment]::NewLine
  [IO.File]::WriteAllText((Join-Path $fixtureAgent 'CLAUDE.md'), $minimalBoot, $Utf8NoBom)

  return $caseRoot
}

function Assert-ValidVaultNote {
  param([Parameter(Mandatory)][string]$LiteralPath)
  $text = [IO.File]::ReadAllText($LiteralPath)
  $normalized = $text.Replace("`r`n", "`n").Replace("`r", "`n")
  Assert-True -Condition $normalized.StartsWith("---`n", [StringComparison]::Ordinal) -Message "frontmatter must begin $LiteralPath"
  $closing = $normalized.IndexOf("`n---`n", 4, [StringComparison]::Ordinal)
  Assert-True -Condition ($closing -gt 4) -Message "frontmatter must close $LiteralPath"
  $frontmatter = $normalized.Substring(4, $closing - 4)
  foreach ($field in @('status', 'project', 'type')) {
    Assert-True -Condition ([regex]::IsMatch($frontmatter, "(?m)^${field}: [^`n]+$")) -Message "frontmatter field $field must exist in $LiteralPath"
  }
  Assert-True -Condition (-not $normalized.Contains('$VaultRoot')) -Message "expanded vault path must not leak a variable token in $LiteralPath"
  Assert-True -Condition (-not $normalized.Contains('[FILL IN:')) -Message "upstream setup placeholder must not remain in $LiteralPath"
  Assert-True -Condition (-not $normalized.Contains('All systems online')) -Message "canned readiness greeting must not appear in $LiteralPath"
  Assert-True -Condition (-not [regex]::IsMatch($normalized, '[\x00-\x08\x0B\x0C\x0E-\x1F]')) -Message "control characters must not appear in $LiteralPath"
}

if (-not (Test-Path -LiteralPath $ScriptUnderTest -PathType Leaf)) {
  throw "Script under test is missing: $ScriptUnderTest"
}
New-Item -ItemType Directory -Path $ScratchRoot -Force | Out-Null

try {
  Invoke-Test 'WhatIf performs zero writes' {
    $caseRoot = New-TestProject -Name 'whatif'
    $before = Get-TreeState -LiteralPath $caseRoot
    & $ScriptUnderTest -ProjectRoot $caseRoot -WhatIf *>&1 | Out-Null
    $after = Get-TreeState -LiteralPath $caseRoot
    Assert-Equal -Expected $before -Actual $after -Message '-WhatIf must not change the fixture tree'
    Assert-True -Condition (-not (Test-Path -LiteralPath (Join-Path $caseRoot 'runtime\memory-vault'))) -Message '-WhatIf must not create the vault'
    Assert-True -Condition (-not (Test-Path -LiteralPath (Join-Path $caseRoot 'runtime\config\MEMORY.md.for-claude'))) -Message '-WhatIf must not create the Claude pointer example'
  }

  $initializedCase = New-TestProject -Name 'initialize'
  & $ScriptUnderTest -ProjectRoot $initializedCase *>&1 | Out-Null

  Invoke-Test 'real initialization creates the complete custom vault' {
    $vaultRoot = Join-Path $initializedCase 'runtime\memory-vault'
    $expectedFiles = @(
      'VAULT-INDEX.md',
      'Active Priorities.md',
      '00 - Inbox\00 - Inbox.md',
      '01 - Daily Notes\01 - Daily Notes.md',
      '01 - Daily Notes\Daily Note Template.md',
      '02 - RemoteJARVIS\02 - RemoteJARVIS.md',
      '03 - Archive\03 - Archive.md',
      '04 - Resources\04 - Resources.md',
      '04 - Resources\Memory Vault Attribution.md'
    )
    foreach ($relativePath in $expectedFiles) {
      Assert-True -Condition (Test-Path -LiteralPath (Join-Path $vaultRoot $relativePath) -PathType Leaf) -Message "expected initialized file $relativePath"
    }
    Assert-Equal -Expected $expectedFiles.Count -Actual @(Get-ChildItem -LiteralPath $vaultRoot -File -Recurse).Count -Message 'initializer must not create undeclared vault files'
  }

  Invoke-Test 'boot and pending Claude pointer use the custom vault path' {
    $vaultRoot = [IO.Path]::GetFullPath((Join-Path $initializedCase 'runtime\memory-vault'))
    $bootPath = Join-Path $initializedCase 'runtime\agent\CLAUDE.md'
    $pointerPath = Join-Path $initializedCase 'runtime\config\MEMORY.md.for-claude'
    $boot = [IO.File]::ReadAllText($bootPath)
    $pointer = [IO.File]::ReadAllText($pointerPath)
    Assert-True -Condition $boot.Contains($vaultRoot, [StringComparison]::OrdinalIgnoreCase) -Message 'boot must point to the custom vault'
    Assert-True -Condition $pointer.Contains($vaultRoot, [StringComparison]::OrdinalIgnoreCase) -Message 'Claude example must point to the custom vault'
    $vaultIndexPosition = $boot.IndexOf('Read VAULT-INDEX.md', [StringComparison]::Ordinal)
    $dailyPosition = $boot.IndexOf("Check yesterday's daily note", [StringComparison]::Ordinal)
    $prioritiesPosition = $boot.IndexOf('Read Active Priorities.md', [StringComparison]::Ordinal)
    Assert-True -Condition (0 -le $vaultIndexPosition -and $vaultIndexPosition -lt $dailyPosition -and $dailyPosition -lt $prioritiesPosition) -Message 'boot must preserve the required startup load order'
    Assert-True -Condition (-not $boot.Contains('memory is not initialized', [StringComparison]::OrdinalIgnoreCase)) -Message 'minimal Stage-Host boot must be upgraded'
    Assert-True -Condition $pointer.Contains('pending example only', [StringComparison]::OrdinalIgnoreCase) -Message 'Claude pointer must remain explicitly pending'
  }

  Invoke-Test 'generated Markdown has valid metadata and intended literal content' {
    $vaultRoot = Join-Path $initializedCase 'runtime\memory-vault'
    foreach ($note in Get-ChildItem -LiteralPath $vaultRoot -Filter '*.md' -File -Recurse) {
      Assert-ValidVaultNote -LiteralPath $note.FullName
    }
    $indexText = [IO.File]::ReadAllText((Join-Path $vaultRoot 'VAULT-INDEX.md'))
    $attributionText = [IO.File]::ReadAllText((Join-Path $vaultRoot '04 - Resources\Memory Vault Attribution.md'))
    $templateText = [IO.File]::ReadAllText((Join-Path $vaultRoot '01 - Daily Notes\Daily Note Template.md'))
    Assert-True -Condition $indexText.Contains([IO.Path]::GetFullPath($vaultRoot), [StringComparison]::OrdinalIgnoreCase) -Message 'vault index must contain the expanded custom path'
    Assert-True -Condition $indexText.Contains('Windows host and AgentBridge work is active', [StringComparison]::Ordinal) -Message 'vault must distinguish active Windows work'
    Assert-True -Condition $indexText.Contains('Apple client implementation is deferred', [StringComparison]::Ordinal) -Message 'vault must distinguish deferred Apple work'
    Assert-True -Condition $attributionText.Contains('upstream/source/jaredrhod-ai-memory-vault-659bba9/LICENSE', [StringComparison]::Ordinal) -Message 'attribution path must survive literally'
    Assert-True -Condition $attributionText.Contains('CC BY-SA 4.0', [StringComparison]::Ordinal) -Message 'adapted template license must be present'
    Assert-True -Condition $templateText.Contains('{{date:YYYY-MM-DD}}', [StringComparison]::Ordinal) -Message 'daily-note template tokens must survive literally'
  }

  Invoke-Test 'rerun preserves every existing file and user boot edits' {
    $bootPath = Join-Path $initializedCase 'runtime\agent\CLAUDE.md'
    $prioritiesPath = Join-Path $initializedCase 'runtime\memory-vault\Active Priorities.md'
    $userNotePath = Join-Path $initializedCase 'runtime\memory-vault\00 - Inbox\User Note.md'
    [IO.File]::AppendAllText($bootPath, "`nUser boot rule.`n", $Utf8NoBom)
    [IO.File]::AppendAllText($prioritiesPath, "`nUser priority edit.`n", $Utf8NoBom)
    [IO.File]::WriteAllText($userNotePath, "---`nstatus: active`nproject: remotejarvis`ntype: reference`n---`n# User Note`n", $Utf8NoBom)
    $before = Get-TreeState -LiteralPath $initializedCase
    & $ScriptUnderTest -ProjectRoot $initializedCase *>&1 | Out-Null
    $after = Get-TreeState -LiteralPath $initializedCase
    Assert-Equal -Expected $before -Actual $after -Message 'idempotent rerun must preserve all existing files byte-for-byte'
    Assert-True -Condition ([IO.File]::ReadAllText($bootPath).Contains('User boot rule.', [StringComparison]::Ordinal)) -Message 'diverged boot file must be preserved'
  }

  Write-Host "Memory initializer tests passed: $Passed"
} finally {
  if (Test-Path -LiteralPath $ScratchRoot) {
    $cleanupTarget = Assert-ContainedScratchPath -LiteralPath $ScratchRoot
    Assert-Equal -Expected $ScratchRoot -Actual $cleanupTarget -Message 'cleanup target must equal the unique test root'
    Remove-Item -LiteralPath $cleanupTarget -Recurse -Force
  }
}
