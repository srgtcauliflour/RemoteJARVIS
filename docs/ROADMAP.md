# RemoteJARVIS Roadmap

## Phase 0 — Repository migration
- Import current source without functional redesign.
- Remove secrets/build products/local-machine artifacts.
- Establish reproducible build instructions.
- Record current known-good behavior.

## Phase 1 — Repository health
- CI for every buildable component.
- Unit tests around protocol/authentication boundaries.
- Formatting/linting.
- Dependency/version documentation.
- Branch protection and review rules.

## Phase 2 — Secure pairing/session baseline
- Preserve first-time passkey pairing design.
- Finalize/document efficient post-pair authentication.
- Device registration/revocation.
- Session expiry/rekey behavior.
- Negative/security tests.

## Phase 3 — Host capability layer
- Typed/capability-scoped host operations.
- Permission checks.
- Audit/events.
- Safe error handling.

## Phase 4 — AI development integrations
- Codex adapter.
- Claude Code adapter.
- Agent/task status model.
- Streaming results/events.
- Permission boundaries around tool execution.

## Phase 5 — iOS experience
- Host management.
- Agent/task views.
- Notifications/state recovery.
- Accessibility.
- Robust offline/reconnect behavior.

## Phase 6 — Contributor scale-up
- Curated `good first issue` set.
- Contributor docs/examples.
- Release automation.
- Public security reporting process.
- Stable protocol/versioning policy.
