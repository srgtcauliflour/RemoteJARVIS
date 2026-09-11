#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Runs the full build/test verification sequence recorded in docs/MIGRATION.md
    against a clean checkout and reports pass/fail per step.

.DESCRIPTION
    Single entry point for reproducing the audited verification results instead
    of copy-pasting each command by hand: Node preflight tests, the installer,
    host-staging and memory-initializer PowerShell suites, the protocol and
    security library Release builds, and the protocol checks console harness
    (see tests/README.md and docs/MIGRATION.md for the authoritative command
    list this script follows).

    Every step always runs, even if an earlier one failed or a prerequisite
    looked wrong -- nothing is silently skipped. Each step's own output is
    shown as it runs, then a pass/fail summary is printed at the end. The
    process exit code is non-zero if any step failed.

    Out of scope (see issue #2): this script verifies and reports, it does
    not fix a check that fails for a reason other than a missing or
    misconfigured tool -- for example the memory-initializer suite requires
    the pinned, gitignored `upstream/source/` fixtures (see tests/README.md)
    and will legitimately fail without them on a truly clean clone.

.EXAMPLE
    pwsh ./scripts/Verify-Build.ps1
#>

[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$RepoRoot = [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$OriginalLocation = Get-Location
Set-Location $RepoRoot

function Write-Heading {
    param([Parameter(Mandatory)][string]$Text)
    Write-Host ''
    Write-Host "== $Text ==" -ForegroundColor Cyan
}

function Test-Prerequisite {
    param(
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][scriptblock]$Check
    )
    try {
        $detail = & $Check
        Write-Host "[ok]   $Name -- $detail" -ForegroundColor Green
    } catch {
        Write-Host "[warn] $Name -- $($_.Exception.Message)" -ForegroundColor Yellow
    }
}

try {
    # -----------------------------------------------------------------
    # Prerequisites (documented per issue #2; reported but not gating --
    # every step below still runs and will fail with its own specific
    # error if a tool is genuinely missing).
    # -----------------------------------------------------------------
    Write-Heading 'Prerequisites'

    Test-Prerequisite -Name '.NET SDK 10.0.401 (pinned in global.json, rollForward disabled)' -Check {
        $sdks = (& dotnet --list-sdks 2>&1) -join "`n"
        if ($LASTEXITCODE -ne 0) { throw "'dotnet --list-sdks' failed: $sdks" }
        if ($sdks -notmatch [regex]::Escape('10.0.401')) {
            throw "not installed. Installed SDKs:`n$sdks"
        }
        'installed'
    }

    Test-Prerequisite -Name 'Node >= 24' -Check {
        $raw = (& node --version 2>&1)
        if ($LASTEXITCODE -ne 0) { throw "'node --version' failed: $raw" }
        $version = $raw.ToString().TrimStart('v')
        $major = [int]($version.Split('.')[0])
        if ($major -lt 24) { throw "found $version, need >= 24" }
        "found $version"
    }

    Test-Prerequisite -Name 'Python >= 3.11 (Backtalk dev guard; not invoked by this sequence)' -Check {
        $cmd = Get-Command python -ErrorAction SilentlyContinue
        if (-not $cmd) { $cmd = Get-Command python3 -ErrorAction SilentlyContinue }
        if (-not $cmd) { throw 'no python or python3 on PATH' }
        $raw = (& $cmd.Path --version 2>&1).ToString()
        $version = ($raw -replace '^Python\s+', '').Trim()
        $parts = $version.Split('.')
        $tooOld = ([int]$parts[0] -lt 3) -or ([int]$parts[0] -eq 3 -and [int]$parts[1] -lt 11)
        if ($tooOld) { throw "found $version, need >= 3.11" }
        "found $version"
    }

    Test-Prerequisite -Name 'PowerShell 7+ / pwsh (required by tests/memory.Tests.ps1)' -Check {
        $edition = $PSVersionTable.PSEdition
        $psVersion = $PSVersionTable.PSVersion
        if ($edition -ne 'Core' -or $psVersion.Major -lt 7) {
            throw ("running $edition $psVersion. tests/memory.Tests.ps1 calls a String.Contains overload " +
                   'that only exists on .NET Core, not .NET Framework, so it fails under Windows PowerShell ' +
                   '5.1 with a Cannot-find-an-overload-for-Contains error partway through. Install PowerShell ' +
                   '7 (pwsh) and re-run this script with it: pwsh ./scripts/Verify-Build.ps1')
        }
        "running $edition $psVersion"
    }

    # -----------------------------------------------------------------
    # Verification sequence, in docs/MIGRATION.md order.
    # -----------------------------------------------------------------
    $Steps = @(
        @{
            Name = 'Node preflight tests (tests/preflight.test.mjs)'
            Run  = { node --test tests/preflight.test.mjs }
        }
        @{
            Name = 'Installer lock/parser tests (tests/installer.Tests.ps1)'
            Run  = { & ./tests/installer.Tests.ps1 }
        }
        @{
            Name = 'Host staging idempotence/WhatIf tests (tests/host-scripts.Tests.ps1)'
            Run  = { & ./tests/host-scripts.Tests.ps1 }
        }
        @{
            Name = 'Memory initializer tests (tests/memory.Tests.ps1)'
            Run  = { & ./tests/memory.Tests.ps1 }
        }
        @{
            Name = 'Protocol library Release build'
            Run  = { dotnet build protocol/AgentBridge.Protocol/AgentBridge.Protocol.csproj -c Release }
        }
        @{
            Name = 'Security library Release build'
            Run  = { dotnet build host/AgentBridge/src/AgentBridge.Security/AgentBridge.Security.csproj -c Release }
        }
        @{
            Name = 'Protocol checks harness (dotnet run, not dotnet test -- see tests/README.md)'
            Run  = { dotnet run --project tests/protocol/AgentBridge.Protocol.Checks.csproj -c Release }
        }
    )

    Write-Heading 'Verification sequence'
    $Results = New-Object System.Collections.Generic.List[pscustomobject]

    foreach ($step in $Steps) {
        Write-Host ''
        Write-Host "--- $($step.Name) ---" -ForegroundColor Cyan
        $stopwatch = [Diagnostics.Stopwatch]::StartNew()
        try {
            & $step.Run
            if ($LASTEXITCODE -and $LASTEXITCODE -ne 0) {
                throw "process exited with code $LASTEXITCODE"
            }
            $stopwatch.Stop()
            $seconds = [math]::Round($stopwatch.Elapsed.TotalSeconds, 1)
            $Results.Add([pscustomobject]@{ Step = $step.Name; Status = 'PASS'; Seconds = $seconds; Detail = '' })
            Write-Host "[pass] $($step.Name) (${seconds}s)" -ForegroundColor Green
        } catch {
            $stopwatch.Stop()
            $seconds = [math]::Round($stopwatch.Elapsed.TotalSeconds, 1)
            $message = $_.Exception.Message
            $Results.Add([pscustomobject]@{ Step = $step.Name; Status = 'FAIL'; Seconds = $seconds; Detail = $message })
            Write-Host "[FAIL] $($step.Name) (${seconds}s)" -ForegroundColor Red
            Write-Host "       $message" -ForegroundColor Red
        }
    }

    # -----------------------------------------------------------------
    # Summary
    # -----------------------------------------------------------------
    Write-Heading 'Summary'
    $Results | Format-Table -AutoSize Step, Status, Seconds | Out-String | Write-Host

    $failedSteps = $Results | Where-Object { $_.Status -ne 'PASS' }
    if ($failedSteps) {
        Write-Host "$($failedSteps.Count) of $($Results.Count) step(s) failed." -ForegroundColor Red
        Write-Host 'This script reports failures; it does not fix a check that fails for a reason' -ForegroundColor Red
        Write-Host 'other than a missing/misconfigured tool (see issue #2 and docs/MIGRATION.md).' -ForegroundColor Red
        $script:ExitCode = 1
    } else {
        Write-Host "All $($Results.Count) verification steps passed." -ForegroundColor Green
        $script:ExitCode = 0
    }
} finally {
    Set-Location $OriginalLocation
}

exit $script:ExitCode
