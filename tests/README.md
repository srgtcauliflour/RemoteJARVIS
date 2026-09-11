# Migration validation

Run from repository root on Windows:

```powershell
node --test tests/preflight.test.mjs
./tests/installer.Tests.ps1
./tests/host-scripts.Tests.ps1
./tests/memory.Tests.ps1
```

The memory tests require the pinned ai-memory-vault source and its license/templates under ignored `upstream/source/`. Test scripts use isolated temporary fixture directories. Do not run them against a live runtime or personal vault.

The archive's `AgentBridge/tests/ProtocolChecks.cs` is preserved as `protocol/ProtocolChecks.cs` under this directory. It has `Run(Action<bool,string>)` but no project, test adapter or entry point in the archive. A normal `dotnet test` invocation does not run it. Add the missing harness as a separate, explicit test-infrastructure change.

Passing these checks does not demonstrate an iOS build, pairing, authenticated remote service or live Claude integration.
