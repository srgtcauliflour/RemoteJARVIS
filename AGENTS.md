# RemoteJARVIS Agent Instructions

This file is the canonical operating contract for Codex, Claude Code, and other coding agents working in this repository.

## 1. Read before changing code

Before implementation, read:

1. `README.md`
2. `docs/ARCHITECTURE.md`
3. `docs/DEVELOPMENT.md`
4. `SECURITY.md`
5. the GitHub issue assigned to the task
6. `docs/IOS-MASTER-SPEC.md` — **mandatory**, in full, before any iOS, AgentBridge, protocol, or authentication/security work. See §5 below.

For component-specific work, inspect the nearest README/AGENTS file if one exists.

## 2. Source of truth

- GitHub issues define work.
- Pull requests define proposed changes.
- `main` is the integration branch and must remain buildable/releasable.
- Architecture decisions documented in `docs/` override assumptions made by an agent.
- Never silently redesign a protocol or security invariant.

## 3. Parallel-agent rules

- One issue -> one primary branch/worktree.
- Never have two agents intentionally modify the same files at the same time.
- Stay within the issue's declared component/file scope.
- If another task is required, create/identify a dependency instead of expanding scope silently.
- Do not directly push to `main`.
- Open a draft PR early for long-running work.
- Rebase/merge latest `main` before final review when practical.

Recommended branch names:

- `feat/<issue>-short-name`
- `fix/<issue>-short-name`
- `docs/<issue>-short-name`
- `test/<issue>-short-name`
- `refactor/<issue>-short-name`

## 4. Agent hierarchy

Use the most capable/expensive model for:

- architecture
- security-sensitive changes
- protocol design
- cross-component integration
- difficult debugging
- final review of large changes

Delegate narrowly-scoped work to faster/lower-cost agents where available:

- boilerplate
- repetitive refactors
- test generation
- formatting/lint cleanup
- documentation updates
- fixture generation
- mechanical migrations

The lead agent remains responsible for integration and correctness.

## 5. RemoteJARVIS security invariants

`docs/IOS-MASTER-SPEC.md` is the full authoritative specification these
invariants are drawn from, including the complete Passkey-pairing
architecture, session-security model, and iOS/AgentBridge system design.
Read it in full before touching iOS, AgentBridge, protocol, or
authentication/security code — the list below is a short-form summary for
quick reference, not a substitute. That document's §87 ("Security
Hierarchy") and §88 ("Passkey Rule — Absolute") are binding on every agent
and every human contributor. Treat them with the same severity as this
section: violating them is not a style nit, it is a security regression.

**iOS SDK currency.** `docs/IOS-MASTER-SPEC.md` fixes iOS 27 / Xcode 27 as
the minimum target. That minimum only moves by an explicit maintainer
decision, but the SDK itself changes constantly, and the spec is explicit
(§2) that the current Apple documentation and SDK win over the document's
own prose whenever they disagree. Before writing or reviewing any iOS,
AgentCore, or AgentBridge platform code: verify the API against the actual
current Apple documentation/SDK rather than training memory or the spec's
descriptions, and record what you verified in `docs/PLATFORM-API-MANIFEST.md`
(create it per the master spec §3 if it doesn't exist yet) — SDK/Xcode/Swift
versions, API availability, entitlements, deprecations, and any divergence
from what the master spec assumed. An agent that ships iOS platform code
without doing this has not satisfied this section.

These may not be changed without an explicit architecture/security issue and maintainer approval:

- A passkey is used for first-time trust establishment/pairing, not as per-request traffic authentication.
- Routine traffic must use efficient cryptographic authentication derived from the paired device/host trust relationship.
- Long-lived reusable bearer secrets must not be written to logs or source control.
- Private keys must remain in platform secure storage where available.
- All remote command execution is authenticated, authorized, scoped, and auditable.
- Never weaken transport security for developer convenience.
- No unauthenticated LAN fallback.
- No hidden remote-control capability.

## 6. Change quality

Every code PR should, where applicable:

- build successfully
- include or update tests
- preserve backwards compatibility or document a migration
- update documentation when behavior/contracts change
- avoid committing generated build products unless required
- avoid unrelated formatting churn

## 7. Definition of done

Before declaring a task complete:

1. Run the relevant tests/lints/build.
2. Review the diff for unrelated changes and secrets.
3. Update docs/tests if contracts changed.
4. Describe risk and validation in the PR.
5. Link the issue using `Closes #<issue>` when appropriate.

## 8. Agent handoff format

When handing work to another agent/person, leave:

- objective
- issue number
- branch/worktree
- files changed
- commands/tests run
- remaining work
- known risks/questions

Do not rely on hidden chat context for critical project state; put durable decisions in GitHub or `docs/`.
