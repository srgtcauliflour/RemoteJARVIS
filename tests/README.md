# Migration validation

`scripts/Verify-Build.ps1` runs the full sequence below end-to-end (plus the
protocol and security Release builds) and reports pass/fail per step instead
of each command being copy-pasted by hand — run `pwsh ./scripts/Verify-Build.ps1`
from the repository root (see issue #2).

Run from repository root on Windows:

```powershell
node --test tests/preflight.test.mjs
./tests/installer.Tests.ps1
./tests/host-scripts.Tests.ps1
./tests/memory.Tests.ps1
dotnet run --project tests/protocol/AgentBridge.Protocol.Checks.csproj -c Release
```

The memory tests require the pinned ai-memory-vault source and its license/templates under ignored `upstream/source/`. Test scripts use isolated temporary fixture directories. Do not run them against a live runtime or personal vault.

The archive's `AgentBridge/tests/ProtocolChecks.cs` is preserved unchanged as `protocol/ProtocolChecks.cs` under this directory. The added console project and entry point invoke its existing 20 checks and fail on unsuccessful checks or an empty run. Use the `dotnet run` command above; this is not a test-adapter project discovered by `dotnet test`.

Passing these checks does not demonstrate an iOS build, pairing, authenticated remote service or live Claude integration.

## Continuous integration

The `build-and-test` job in `.github/workflows/repo-health.yml` runs
`pwsh ./scripts/Verify-Build.ps1` on Windows for every pull request and push
to `main`. It installs Node 24, Python 3.12, and the exact .NET SDK selected
by `global.json`, then checks out `ai-memory-vault` at the commit and source
directory recorded in `Configuration/upstream.lock.json` so the memory
tests have their required fixtures.

The verification script runs all seven build/test steps, reports each
result, and exits nonzero if any step fails. The existing repository policy
and publication checks run separately in the `validate-repository` job.
