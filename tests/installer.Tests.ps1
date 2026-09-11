$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent (Split-Path -Parent $PSCommandPath)
$lock = Get-Content -Raw (Join-Path $root 'Configuration\toolchain.lock.json') | ConvertFrom-Json
if ($lock.tools.uv.url -notmatch '^https://github\.com/astral-sh/uv/releases/download/0\.12\.13/') { throw 'uv URL is not pinned' }
if ($lock.tools.git.url -notmatch '^https://github\.com/git-for-windows/git/releases/download/v2\.55\.0\.windows\.5/') { throw 'git URL is not pinned' }
foreach ($s in @($lock.tools.uv,$lock.tools.git,$lock.tools.claude,$lock.tools.espeak)) { if ([IO.Path]::GetFileName($s.artifact) -ne $s.artifact) { throw 'unsafe artifact path' }; if ($s.url -notmatch '^https://') { throw 'non-HTTPS artifact URL' }; if (-not $s.observedSha256 -or $s.observedSha256.Length -ne 64) { throw 'missing observed hash' } }
$script = Join-Path $root 'scripts\Install-HostTools.ps1'; $tokens=$null;$errors=$null;[System.Management.Automation.Language.Parser]::ParseFile((Resolve-Path $script),[ref]$tokens,[ref]$errors)|Out-Null; if($errors){throw ($errors|Out-String)}
Write-Host 'installer lock and parser tests passed'
