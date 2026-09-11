[CmdletBinding(SupportsShouldProcess)]
param(
  [string]$ProjectRoot,
  [string]$SourceRoot,
  [string]$RuntimeRoot
)
$ErrorActionPreference = 'Stop'
if (-not $ProjectRoot) { $ProjectRoot = Split-Path -Parent $PSScriptRoot }
if (-not $SourceRoot) { $SourceRoot = Join-Path $ProjectRoot 'upstream\source' }
if (-not $RuntimeRoot) { $RuntimeRoot = Join-Path $ProjectRoot 'runtime' }

$sources = @{
  'fullstack-agent' = 'jaredrhod-fullstack-agent-5bb159f'
  'backtalk' = 'jaredrhod-backtalk-84b3a6c'
  'ai-visualizer' = 'jaredrhod-ai-visualizer-6921e1d'
  'ai-memory-vault' = 'jaredrhod-ai-memory-vault-659bba9'
  'barehands' = 'jaredrhod-barehands-eb23bed'
}
$agentRoot = Join-Path $RuntimeRoot 'agent'
$resolvedSources = @{}
foreach ($name in $sources.Keys) {
  $source = Join-Path $SourceRoot $sources[$name]
  if (-not (Test-Path -LiteralPath $source -PathType Container)) { throw "Missing source snapshot: $source" }
  $resolvedSources[$name] = $source
}
if ($PSCmdlet.ShouldProcess($RuntimeRoot, 'create runtime directories')) { New-Item -ItemType Directory -Force -Path (Join-Path $RuntimeRoot 'config'), (Join-Path $RuntimeRoot 'state'), $agentRoot | Out-Null }
foreach ($name in $sources.Keys) {
  $target = Join-Path $agentRoot $name
  if (Test-Path -LiteralPath $target) { Write-Host "[keep] $name already staged"; continue }
  $source = $resolvedSources[$name]
  if ($PSCmdlet.ShouldProcess($target, "stage $name snapshot")) {
    $staging = "$target.staging-$([guid]::NewGuid().ToString('N'))"
    try { Copy-Item -LiteralPath $source -Destination $staging -Recurse; Move-Item -LiteralPath $staging -Destination $target }
    finally { if (Test-Path -LiteralPath $staging) { Remove-Item -LiteralPath $staging -Recurse -Force } }
    Write-Host "[stage] $name"
  }
}

$memory = Join-Path $RuntimeRoot 'memory-vault'
if (-not (Test-Path -LiteralPath $memory) -and $PSCmdlet.ShouldProcess($memory, 'create empty memory vault')) { New-Item -ItemType Directory -Path $memory | Out-Null }
$signals = Join-Path $RuntimeRoot 'state\backtalk'
if ($PSCmdlet.ShouldProcess($signals, 'create signal directory')) { New-Item -ItemType Directory -Force -Path $signals | Out-Null }
$backtalkConfig = Join-Path $RuntimeRoot 'config\backtalk.json'
if (-not (Test-Path -LiteralPath $backtalkConfig) -and $PSCmdlet.ShouldProcess($backtalkConfig, 'write Backtalk config')) {
  @{
    agent_dir = $agentRoot; name = 'RemoteJARVIS'; permission_mode = 'ask'; mic_mode = 'ptt'; voice = 'bm_lewis'; show_usage = $false; resume_last_session = $true; extra_dirs = @($memory); signals_dir = $signals
  } | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $backtalkConfig -Encoding utf8
  Write-Host "[write] $backtalkConfig"
} else { Write-Host "[keep] existing backtalk config" }
$visualizerConfig = Join-Path $agentRoot 'ai-visualizer\ai-visualizer.json'
if (-not (Test-Path -LiteralPath $visualizerConfig) -and $PSCmdlet.ShouldProcess($visualizerConfig, 'write visualizer config')) {
  @{ bus_dir = $signals; name = 'RemoteJARVIS' } | ConvertTo-Json | Set-Content -LiteralPath $visualizerConfig -Encoding utf8
  Write-Host "[write] $visualizerConfig"
} else { Write-Host "[keep] existing visualizer config" }
$claude = Join-Path $agentRoot 'CLAUDE.md'
if (-not (Test-Path -LiteralPath $claude) -and $PSCmdlet.ShouldProcess($claude, 'write CLAUDE.md')) {
  @"
# RemoteJARVIS

You are RemoteJARVIS. Your memory path is $memory (the vault is new and memory is not initialized).
Respect project permissions and ask before actions that change files, run commands, or affect external systems. Do not bypass permissions.
"@ | Set-Content -LiteralPath $claude -Encoding utf8
  Write-Host "[write] $claude"
} else { Write-Host "[keep] existing CLAUDE.md" }
Write-Host "Host staging complete. Runtime: $RuntimeRoot"
