# RemoteJARVIS Architecture

This document captures stable boundaries for collaborative development. Replace TODOs with the exact implementation as the current project is migrated.

## Components

### iOS client (`ios/`)

See `docs/IOS-MASTER-SPEC.md` for the full, authoritative iOS/AgentBridge build specification and authentication architecture — required reading before implementing this component.

Responsibilities:
- mobile UI
- first-time host pairing
- secure local credential/key storage
- authenticated session establishment
- presentation of host/agent state
- sending explicitly authorized user actions

### Host service (`host/`)

Responsibilities:
- pairing endpoint/workflow
- device registration and revocation
- authenticated sessions
- authorization enforcement
- orchestration of local development tools
- audit/event generation
- safe exposure of host capabilities to the mobile client

### Protocol (`protocol/`)

Owns wire contracts independent of UI/host implementation:
- message schemas
- version negotiation
- authentication/session messages
- errors
- capability negotiation
- compatibility policy

### Integrations (`integrations/`)

Adapters for development assistants/tools such as Codex and Claude Code. Integration-specific behavior must not leak into the core transport protocol unless explicitly designed as a capability.

## Trust lifecycle

```text
Unpaired mobile
   |
   | first-time pairing + passkey confirmation
   v
Paired device identity
   |
   | efficient device/session authentication
   v
Authenticated session
   |
   | explicit authorization + capability checks
   v
Host operation / agent request
```

The first-time passkey is not intended to authenticate every request.

## Security boundaries

1. Mobile secure storage boundary.
2. Network boundary between mobile and host.
3. Host authorization boundary.
4. Agent/tool execution boundary.
5. Repository/CI secrets boundary.

Changes crossing more than one boundary should generally be split into reviewable commits/PRs or accompanied by an architecture note.

## Protocol evolution

Protocol changes should include:
- version impact
- backwards compatibility behavior
- migration plan
- tests for both valid and invalid messages

## TODO during migration

- Document current language/framework for host service.
- Record the exact post-pairing authentication scheme already chosen/implemented. A concrete proposal is drafted in `docs/ADR/0002-post-pair-authentication.md` — status Proposed, awaiting maintainer acceptance (issue #5); this TODO stays open until that ADR is accepted.
- Document connection discovery/routing model.
- Document remote-build/compilation path for iOS.
- Record Codex/Claude integration interfaces and permission boundaries.
