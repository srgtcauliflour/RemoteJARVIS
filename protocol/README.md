# Protocol boundary

`AgentBridge.Protocol/` contains the unchanged .NET protocol library from `AgentBridge/src/AgentBridge.Protocol/` in the source archive. It implements envelope validation/serialization, including protocol version, session/sequence checks, bounded timestamps and payload checks. It does not implement the cryptographic transport or pairing.

`Directory.Build.props` and `global.json` at repository root retain the original inherited settings and SDK pin. Existing protocol check source is preserved in `tests/protocol/ProtocolChecks.cs`; the archive supplies no executable test harness/project for it.

The documented TLS 1.3 mutual-authentication approach is a proposal with unresolved feasibility gates. This migration neither approves that proposal nor changes it.
