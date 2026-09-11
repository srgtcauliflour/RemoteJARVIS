[CmdletBinding()]
param([ValidateSet('doctor','sync','chat','voice','visualizer')][string]$Command = 'doctor')
$ErrorActionPreference = 'Stop'
$Root = Split-Path -Parent $PSScriptRoot
$Runtime = Join-Path $Root 'runtime'; $Agent = Join-Path $Runtime 'agent'; $Backtalk = Join-Path $Agent 'backtalk'; $Visualizer = Join-Path $Agent 'ai-visualizer'
$PortableUv = Join-Path $Root '.tools\uv\uv.exe'; $PortablePython = Join-Path $Root '.tools\python\cpython-3.12.14-windows-x86_64-none\python.exe'; $Claude = Join-Path $Root '.tools\claude\claude.exe'
$GitRoot = Join-Path $Root '.tools\git'; $GitBash = Join-Path $GitRoot 'bin\bash.exe'
$env:PATH = "$(Join-Path $Root '.tools\uv');$(Split-Path $PortablePython);$(Join-Path $Root '.tools\claude');$(Join-Path $GitRoot 'cmd');$(Join-Path $GitRoot 'usr\bin');$env:PATH"
$env:CLAUDE_CODE_GIT_BASH_PATH = $GitBash
$env:UV_CACHE_DIR = Join-Path $Root '.tools\uv-cache'; $env:UV_PYTHON_INSTALL_DIR = Join-Path $Root '.tools\python'
$env:HF_HOME = Join-Path $Root '.tools\models\huggingface'
$env:TORCH_HOME = Join-Path $Root '.tools\models\torch'
$env:PHONEMIZER_ESPEAK_LIBRARY = Join-Path $Root '.tools\espeak\eSpeak NG\libespeak-ng.dll'
$env:ESPEAK_DATA_PATH = Join-Path $Root '.tools\espeak\eSpeak NG\espeak-ng-data'
$env:PYTHONNOUSERSITE = '1'
switch ($Command) {
  'doctor' {
    Write-Host "RemoteJARVIS host doctor (read-only)"
    foreach ($p in @($PortableUv,$PortablePython,$Claude,$Backtalk,$Visualizer,(Join-Path $Runtime 'config\backtalk.json'))) { Write-Host "$(if(Test-Path -LiteralPath $p){'[ready]'}else{'[missing]'}) $p" }
  }
  'sync' {
    if (-not (Test-Path -LiteralPath $PortableUv)) { throw "Portable uv missing: $PortableUv" }
    if (-not (Test-Path -LiteralPath $PortablePython)) { throw "Portable Python missing: $PortablePython" }
    & $PortableUv sync --project $Backtalk --python $PortablePython
    if ($LASTEXITCODE -ne 0) { throw "uv sync failed with exit code $LASTEXITCODE" }
    & $PortableUv pip install --python (Join-Path $Backtalk '.venv\Scripts\python.exe') --requirements (Join-Path $Root 'Configuration\backtalk.runtime-requirements.txt')
    if ($LASTEXITCODE -ne 0) { throw "Voice language pipeline install failed with exit code $LASTEXITCODE" }
  }
  'chat' {
    if (-not (Test-Path -LiteralPath $Claude)) { throw "Claude CLI missing: $Claude" }
    Push-Location $Agent; try { & $Claude; if ($LASTEXITCODE -ne 0) { throw "Claude exited with code $LASTEXITCODE" } } finally { Pop-Location }
  }
  'voice' {
    if (-not (Test-Path -LiteralPath $PortableUv)) { throw "Portable uv missing: $PortableUv" }
    $env:BACKTALK_CONFIG = Join-Path $Runtime 'config\backtalk.json'
    $env:TEMP = Join-Path $Runtime 'temp'; $env:TMP = $env:TEMP
    New-Item -ItemType Directory -Path $env:TEMP -Force | Out-Null
    Push-Location $Backtalk; try { & $PortableUv run --no-sync python -m backtalk.main; if ($LASTEXITCODE -ne 0) { throw "Backtalk exited with code $LASTEXITCODE" } } finally { Pop-Location }
  }
  'visualizer' {
    if (-not (Test-Path -LiteralPath $PortablePython)) { throw "Portable Python missing: $PortablePython" }
    Push-Location $Visualizer; try { & $PortablePython server.py; if ($LASTEXITCODE -ne 0) { throw "Visualizer exited with code $LASTEXITCODE" } } finally { Pop-Location }
  }
}
