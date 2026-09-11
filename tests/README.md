# Migration validation

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
