# Host boundary

`AgentBridge/src/AgentBridge.Security/` contains the existing Windows host-identity and device-trust foundation. It is a library, not a runnable service. Migration preserves its C# source unchanged.

The shared .NET SDK pin and build properties are at repository root. Existing host installation and local launch scripts remain in root `scripts/`, with `Configuration/` beside it, because they resolve `.tools/`, `upstream/`, `runtime/` and configuration relative to that root.

The input snapshot has CA1416 build errors at `TrustRegistry.cs` lines 35 and 101 under SDK 10.0.401. Resolve the Windows platform declaration in a separately reviewed build fix; do not suppress warnings or change authentication to hide the failure.

See `docs/MIGRATION.md` for the exact snapshot, build commands, limits and remaining gates.
