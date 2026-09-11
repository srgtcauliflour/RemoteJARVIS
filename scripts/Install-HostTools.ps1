[CmdletBinding(SupportsShouldProcess)]
param([string]$ProjectRoot = (Split-Path -Parent $PSScriptRoot))
$ErrorActionPreference = 'Stop'
if (-not ([Environment]::Is64BitOperatingSystem) -or $env:OS -ne 'Windows_NT') { throw 'Install-HostTools supports Windows x64 only.' }
$lockPath = Join-Path $ProjectRoot 'Configuration\toolchain.lock.json'
$lock = Get-Content -Raw -LiteralPath $lockPath | ConvertFrom-Json
$tools = Join-Path $ProjectRoot '.tools'; $downloads = Join-Path $tools 'downloads'; $cache = Join-Path $tools 'uv-cache'
function Assert-Contained([string]$Path, [string]$Parent) {
  $p = [IO.Path]::GetFullPath($Path); $q = [IO.Path]::GetFullPath($Parent).TrimEnd([IO.Path]::DirectorySeparatorChar) + [IO.Path]::DirectorySeparatorChar
  if (-not ($p.StartsWith($q, [StringComparison]::OrdinalIgnoreCase))) { throw "Path escapes permitted root: $Path" }
  return $p
}
function Ensure-Dir([string]$Path) { if (-not (Test-Path -LiteralPath $Path) -and $PSCmdlet.ShouldProcess($Path, 'create directory')) { New-Item -ItemType Directory -Force -Path $Path | Out-Null } }
function Assert-Spec($Spec) {
  $uri = [Uri]$Spec.url
  if ($uri.Scheme -ne 'https' -or $uri.Host -notin @('github.com','downloads.claude.ai')) { throw "Unapproved HTTPS origin: $($Spec.url)" }
  if ([IO.Path]::GetFileName($Spec.artifact) -ne $Spec.artifact -or $Spec.artifact -match '[\\/]') { throw "Unsafe artifact filename: $($Spec.artifact)" }
  if ($Spec.url -notmatch '/releases/download/[^/]+/' -and $Spec.url -notmatch '^https://downloads\.claude\.ai/claude-code-releases/[^/]+/') { throw "URL is not a pinned release asset: $($Spec.url)" }
}
function Get-VerifiedArtifact($Spec) {
  Assert-Spec $Spec; $expected = if ($Spec.publisherSha256) { $Spec.publisherSha256 } else { $Spec.observedSha256 }; $target = Join-Path $downloads $Spec.artifact; Assert-Contained $target $downloads | Out-Null
  if (Test-Path -LiteralPath $target) {
    $hash = (Get-FileHash -LiteralPath $target -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($hash -eq $expected) { Write-Host "[keep] verified $($Spec.artifact)"; return $target }
    if (-not $PSCmdlet.ShouldProcess($target, 'replace corrupt cached artifact')) { return $null }
  } elseif (-not $PSCmdlet.ShouldProcess($target, "download $($Spec.url)")) { return $null }
  $tmp = Assert-Contained (Join-Path $downloads (".$($Spec.artifact).$([guid]::NewGuid().ToString('N')).tmp") $downloads)
  try {
    Invoke-WebRequest -Uri $Spec.url -OutFile $tmp -UseBasicParsing
    $hash = (Get-FileHash -LiteralPath $tmp -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($hash -ne $expected) { throw "SHA256 mismatch for $($Spec.artifact)" }
    Move-Item -LiteralPath $tmp -Destination $target -Force
    return $target
  } finally { if (Test-Path -LiteralPath $tmp) { Remove-Item -LiteralPath $tmp -Force } }
}
Ensure-Dir $tools; Ensure-Dir $downloads; Ensure-Dir $cache
$uvZip = Get-VerifiedArtifact $lock.tools.uv; $git7z = Get-VerifiedArtifact $lock.tools.git; $claudeArtifact = Get-VerifiedArtifact $lock.tools.claude; $espeakMsi = Get-VerifiedArtifact $lock.tools.espeak
if ($uvZip) {
  $uvTarget = Join-Path $tools 'uv\uv.exe'; if (-not (Test-Path -LiteralPath $uvTarget) -and $PSCmdlet.ShouldProcess($uvTarget, 'extract verified uv archive')) {
    $stage = Assert-Contained (Join-Path $tools ('.uv-stage-' + [guid]::NewGuid().ToString('N'))) $tools
    try { Expand-Archive -LiteralPath $uvZip -DestinationPath $stage -Force; $candidate = Join-Path $stage 'uv.exe'; if (-not (Test-Path -LiteralPath $candidate)) { $candidate = Join-Path $stage 'uv-x86_64-pc-windows-msvc\uv.exe' }; if (-not (Test-Path -LiteralPath $candidate)) { throw 'uv.exe not found in archive' }; Ensure-Dir (Split-Path $uvTarget); Copy-Item -LiteralPath $candidate -Destination $uvTarget }
    finally { if (Test-Path -LiteralPath $stage) { Remove-Item -LiteralPath $stage -Recurse -Force } }
  }
}
if ($git7z -and -not (Test-Path -LiteralPath (Join-Path $tools 'git\cmd\git.exe')) -and $PSCmdlet.ShouldProcess((Join-Path $tools 'git'), 'extract verified Git archive')) {
  Ensure-Dir (Join-Path $tools 'git'); $gitTarget = Assert-Contained (Join-Path $tools 'git') $tools; $args = @('-y', "-o`"$gitTarget`""); $p = Start-Process -FilePath $git7z -ArgumentList $args -WindowStyle Hidden -Wait -PassThru; if ($p.ExitCode -ne 0) { throw "Git extraction failed with exit code $($p.ExitCode)" }
}
if ($claudeArtifact) { $claudeTarget = Join-Path $tools 'claude\claude.exe'; if (-not (Test-Path -LiteralPath $claudeTarget) -and $PSCmdlet.ShouldProcess($claudeTarget, 'copy verified Claude CLI')) { Ensure-Dir (Split-Path $claudeTarget); Copy-Item -LiteralPath $claudeArtifact -Destination $claudeTarget } }
if ($espeakMsi -and -not (Test-Path -LiteralPath (Join-Path $tools 'espeak\eSpeak NG\libespeak-ng.dll')) -and $PSCmdlet.ShouldProcess((Join-Path $tools 'espeak'), 'extract verified eSpeak MSI')) { $espeakTarget = Assert-Contained (Join-Path $tools 'espeak') $tools; Ensure-Dir $espeakTarget; $p = Start-Process -FilePath 'msiexec.exe' -ArgumentList @('/a', $espeakMsi, '/qn', ('TARGETDIR="{0}"' -f $espeakTarget)) -WindowStyle Hidden -Wait -PassThru; if ($p.ExitCode -ne 0) { throw "eSpeak extraction failed with exit code $($p.ExitCode)" } }
$uv = Join-Path $tools 'uv\uv.exe'; $python = Join-Path $tools 'python\cpython-3.12.14-windows-x86_64-none\python.exe'
if ((Test-Path -LiteralPath $uv) -and $PSCmdlet.ShouldProcess($python, 'install pinned Python with uv')) { $env:UV_CACHE_DIR = $cache; $env:UV_PYTHON_INSTALL_DIR = Join-Path $tools 'python'; & $uv python install $lock.python.version --install-dir $env:UV_PYTHON_INSTALL_DIR --no-bin --no-registry --no-config; if ($LASTEXITCODE -ne 0) { throw "uv Python install failed with exit code $LASTEXITCODE" } }
if (-not $WhatIfPreference) {
  function Validate-Tool([string]$Path, [string]$ExpectedHash, [string]$ExpectedVersion, [string]$Label) {
    if (-not (Test-Path -LiteralPath $Path)) { return }
    $actual=(Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant(); if ($actual -ne $ExpectedHash) { throw "Refusing to execute unrecognized $Label hash $actual" }
    $text = (& $Path --version | Out-String).Trim(); if ($LASTEXITCODE -ne 0 -or $text -notmatch ([regex]::Escape($ExpectedVersion))) { throw "$Label version validation failed (expected $ExpectedVersion; got $text)" }
  }
  Validate-Tool $uv $lock.installedObservedSha256.'uv.exe' $lock.tools.uv.version 'uv'
  if (Test-Path -LiteralPath $python) { $text = (& $python --version | Out-String).Trim(); if ($LASTEXITCODE -ne 0 -or $text -notmatch 'Python 3\.12\.14') { throw "Python version validation failed (got $text)" } }
  Validate-Tool (Join-Path $tools 'git\cmd\git.exe') $lock.installedObservedSha256.'git.exe' $lock.tools.git.version 'Git'
  Validate-Tool (Join-Path $tools 'claude\claude.exe') $lock.installedObservedSha256.'claude.exe' $lock.tools.claude.version 'Claude'
}
if ($WhatIfPreference) { Write-Host 'Toolchain install plan complete; no writes, network requests, or executable launches were performed.' } else { Write-Host 'Toolchain install complete; account, license, and authentication configuration remain pending.' }
