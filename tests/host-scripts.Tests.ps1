$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent (Split-Path -Parent $PSCommandPath)
$temp = Join-Path $root ('.host-test-' + [guid]::NewGuid().ToString('N'))
try {
  $src = Join-Path $temp 'source'; $run = Join-Path $temp 'runtime'
  foreach ($d in @('jaredrhod-fullstack-agent-5bb159f','jaredrhod-backtalk-84b3a6c','jaredrhod-ai-visualizer-6921e1d','jaredrhod-ai-memory-vault-659bba9','jaredrhod-barehands-eb23bed')) { New-Item -ItemType Directory -Force (Join-Path $src $d) | Out-Null }
  $stage = Join-Path $root 'scripts\Stage-Host.ps1'
  & $stage -SourceRoot $src -RuntimeRoot $run
  foreach ($p in @('agent\fullstack-agent','agent\backtalk','agent\ai-visualizer','agent\ai-memory-vault','agent\barehands','config\backtalk.json','agent\ai-visualizer\ai-visualizer.json','agent\CLAUDE.md','memory-vault')) { if (-not (Test-Path (Join-Path $run $p))) { throw "missing staged path: $p" } }
  $before = (Get-ChildItem $run -Recurse -Force | ForEach-Object FullName) -join '|'
  & $stage -SourceRoot $src -RuntimeRoot $run
  $after = (Get-ChildItem $run -Recurse -Force | ForEach-Object FullName) -join '|'; if ($before -ne $after) { throw 'rerun was not idempotent' }
  $whatIf = Join-Path $temp 'whatif'; & $stage -SourceRoot $src -RuntimeRoot $whatIf -WhatIf
  if (Test-Path $whatIf) { throw '-WhatIf wrote files' }
  Write-Host 'host script smoke tests passed'
} finally { if (Test-Path $temp) { Remove-Item -LiteralPath $temp -Recurse -Force } }
