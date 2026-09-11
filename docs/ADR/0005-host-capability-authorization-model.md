# ADR-0005: Host Capability Authorization Model

## Status

**Proposed.** Not implemented. Per issue #6 this defines the security
boundary for every command an agent can issue against the host and
explicitly requires maintainer/lead review before any implementation
starts — "not a pick-up-and-go task."

**Drafted ahead of its blocker, deliberately.** Issue #6 is formally
"Blocked by #5," and this ADR also depends on capability negotiation from
ADR‑0003 (issue #9) and the event model from ADR‑0004 (issue #12) —
neither #5 nor #9 has landed yet (PR #20 is still draft; ADR‑0003 isn't
even opened as a PR yet). This ADR is written assuming ADR‑0002 and
ADR‑0003 land close to their current drafted form. If either changes
materially during review, this ADR's cross‑references (§1's dispatch
ordering, in particular) need revisiting before acceptance — that
dependency is stated here plainly rather than discovered later, the same
way ADR‑0002 originally had to be reconciled against ADR‑0001 after the
fact.

## Context

### What issue #6 actually asks

Define what a paired, authenticated device may actually *do* on the
host — a separate question from #5 (who the device is). Build on
`TrustRegistry.cs`'s existing structure rather than a parallel permission
store. Explicitly asks whether authorization should be host‑wide,
per‑capability, or per‑agent‑session, and how that maps onto existing
protocol message types.

### What already exists (ground truth)

`TrustRegistry.cs` (`host/AgentBridge/src/AgentBridge.Security/`, real,
implemented) already has: a `PermissionLevel` enum — `Observe, Chat,
Operate, ModifyFiles, ExecuteCommands, Destructive` — a `TrustedDevice`
record carrying a single `MaximumPermission` per device, and
`IsAuthorized(deviceId, requiredLevel)` as a standalone check, separate
from `Authenticate()`. `docs/ADR/0002-post-pair-authentication.md` §3
already committed to two hard requirements this ADR inherits rather than
re‑decides: enforcement must be **per‑operation, not per‑session**, and
approvals are **a policy layer on top of `PermissionLevel`**, not a
replacement for it.

### What the master spec fixes as given

`docs/IOS-MASTER-SPEC.md` §33 fixes the permission scale itself as a
single linear ladder — LEVEL 0 Observe, 1 Chat, 2 Non‑destructive
operations, 3 File modifications, 4 Command execution, 5
Destructive/system operations — already an exact match for
`PermissionLevel`, and states plainly: "AgentBridge enforces it. The
iPhone UI does not enforce it alone." §34 requires first‑class approval
objects the server must independently verify, warning explicitly: "Never
trust a forged client approval message." §35 requires five emergency
controls (Stop Agent, Disconnect Host, Lock Remote Control, Revoke
Device, Revoke All Devices) that "must not depend on the AI responding."
§52/§53 require canonicalized‑path file security and host‑enforced
terminal command policy, both stating the host must enforce them, not
the iOS app. §55 fixes what must and must not be logged.

### Relationship to ADR-0003 and ADR-0004

ADR‑0003 (capability negotiation, drafted) left an explicit open
question: where does "is this connection allowed to use capability X at
all" (its own layer) sit relative to `TrustRegistry.IsAuthorized` (this
ADR's layer)? §1 below answers that directly. ADR‑0004 (event model,
drafted, PR #21) defines `tool.*`/`approval.*` events and their payload
shapes but deliberately left *when* an approval is required and *how* a
decision is verified to this ADR — §3/§4 below answer that.

## Decision

### 1. One linear scale, per-operation classification — not a separate per-capability matrix

Issue #6 asks directly whether authorization should be host‑wide,
per‑capability, or per‑agent‑session. This ADR's answer: **per‑operation,
against one host‑wide linear scale** — not a second, independent
permission matrix keyed by capability.

Every dispatchable operation — every `tool.*` invocation (ADR‑0004 §4)
and every other privileged AgentBridge API call (file, terminal, project,
memory, per §23) — is classified, once, against the same LEVEL 0–5 scale
§33 already fixes. A device's authorization for that operation is exactly
`TrustedDevice.MaximumPermission >= operation.RequiredLevel`, using the
already‑implemented `IsAuthorized(deviceId, requiredLevel)` unchanged.
This is deliberately *not* per‑capability (no separate "may this device
use `shell.exec` at all" table distinct from "may this device do
LEVEL‑4 things") and *not* per‑agent‑session (a device's ceiling doesn't
change mid‑session; only revocation changes it, and revocation already
closes the session per ADR‑0002 §2) — both would be a second source of
truth alongside `TrustedDevice.MaximumPermission`, which is exactly the
"parallel permission store" issue #6 says not to build.

**Where this composes with ADR-0003's capability negotiation:** the two
checks are sequential and independent, answering different questions.
Dispatch order for any inbound operation:

1. Transport authenticated (ADR‑0001/ADR‑0002 — is this a real,
   trusted‑device mTLS connection).
2. Capability negotiated (ADR‑0003 §2 — does *this connection* support
   this message type at all; rejects with `capabilityUnsupported` if
   not).
3. **Authorization (this ADR) — is *this device* allowed to do this,
   regardless of what the connection negotiated** (`IsAuthorized`;
   rejects with a distinct authorization‑failure code, not
   `capabilityUnsupported` — a capability gap and a permission denial are
   different failure modes and must be distinguishable, per §54's mandate
   to test authorization failure as its own category).
4. Approval, if this specific operation requires one (§3 below).
5. Execute; emit `tool.started` (ADR‑0004).

This directly closes ADR‑0003's open question #3: capability negotiation
is strictly upstream of, and independent from, `TrustRegistry`
authorization. A device can have `shell.exec` negotiated (the connection
supports it) and still be denied at step 3 (this specific device isn't
LEVEL‑4). Neither check substitutes for the other, matching ADR‑0004 §4's
own statement that it doesn't re‑validate capability negotiation inside
the event model.

### 2. Per-operation classification tables for file and terminal operations (§52, §53)

These two areas get concrete rules because the spec is explicit that the
host — not the app — enforces them, and because they're the two
categories §54 devotes the most mandatory test cases to.

**File operations:** every path is canonicalized and checked against a
permitted‑roots allowlist **before** permission‑level classification even
runs — a path outside the allowed roots is rejected outright, regardless
of the device's `MaximumPermission`; this is a hard boundary per §52
("Never trust client‑supplied paths"), not a permission tier. Within an
allowed root: read = LEVEL 0 (Observe); write/modify an existing file or
create a new one = LEVEL 3 (File modifications, matching §33's own
naming); delete = LEVEL 5 (Destructive) **and** always requires an
approval regardless of the device's ceiling, matching §34's own example
("Delete file?") and consistent with ADR‑0002 §3's "approvals answer 'is
this specific action allowed right now,' not just 'is this class of
action ever allowed.'"

**Terminal operations:** every command is classified before execution,
minimum LEVEL 4 (Command execution) to run anything at all. A
maintainer‑defined risk classification (not designed here — flagged as
Open Question #1) escalates specific destructive command patterns to
LEVEL 5 plus a mandatory approval, independent of the device's own
ceiling — the same "approval on top of level" composition as file
deletion. Rate limiting and full command logging (§53, §55) apply
regardless of level.

### 3. Approval objects — server-issued, server-verified, never client-authored

An `ApprovalRequest` is created *by the host*, not the client, the moment
step 4 of §1's dispatch order determines an operation needs one. Its
shape matches §34's own display requirements exactly: `{ approvalId,
taskId, toolCallId?, requiredAction, target, project, riskLevel,
explanation, requiredPermissionLevel }`. This is emitted as ADR‑0004's
`approval.required` event.

**Anti‑forgery, directly answering §34's "never trust a forged client
approval message":** the client's `approval.approved`/`approval.denied`
response carries only `{ approvalId, decision }` — it never re‑sends the
action, target, or parameters. The host looks up what that `approvalId`
was actually for from its own server‑side record (created in the step
above) and re‑executes exactly that, never anything reconstructed from
client‑supplied fields. A client cannot approve action A and have the
host execute action B, because the host never asks the client what
action it's approving — only which `approvalId`.

**Expiry and single use:** an `ApprovalRequest` is valid for a bounded
window (proposed default: 5 minutes — not load‑bearing to the design,
open to maintainer adjustment) and is consumed on first use; a second
`approval.approved` for the same `approvalId` is rejected. This is what
makes "forged approval" (§54's own mandatory test case) and replay
testable as a concrete pass/fail condition rather than an aspiration.

### 4. Emergency controls bypass the agent/event pipeline, not authorization itself

§35's five controls (Stop Agent, Disconnect Host, Lock Remote Control,
Revoke Device, Revoke All Devices) "must not depend on the AI
responding." This ADR reads that as: they must not be routed through the
agent adapter or ADR‑0004's task/tool event pipeline at all — a hung or
unresponsive Codex/Claude Code worker process must not be able to block
them. They're dispatched directly by AgentBridge's own control plane
(the same layer that already owns `TrustRegistry`), independent of
whether any adapter process is alive.

This does **not** mean they bypass authorization itself — "must not
depend on the AI responding" is about the agent's liveness, not about
skipping §1's dispatch chain. `Stop Agent` and `Disconnect Host` are
scoped to the connection's own session and require no elevated level
beyond ordinary session control. `Revoke Device` / `Revoke All Devices`
call the already‑implemented `TrustRegistry.Revoke()` directly — but
*whose* devices a given connection may revoke (only its own? any
device, if the connecting device is some form of "owner"?) is not
resolved by this ADR — flagged as Open Question #2, since the spec
doesn't define an ownership/admin concept beyond the single‑user model
`docs/MIGRATION.md` describes, and inventing one here would be exactly
the kind of unreviewed security‑model decision §85 says to stop and ask
about.

### 5. Security auditing

One append‑only audit record per authorization decision — not just
denials — covering every operation classified at LEVEL 2 or above (the
line §33 itself draws at "Non‑destructive operations"), shaped as: `{
timestamp, deviceId, sessionId, action, requiredLevel, deviceMaxLevel,
decision: allow|deny, approvalId? }`. This satisfies §55's requirement to
log both "privileged actions" and "authorization failure" as related but
distinct entries, generated from the same dispatch chokepoint in §1 so
there's exactly one place that can under‑log. §55's "never log" list —
private keys, passwords, session secrets, unnecessary conversation
contents — is adopted verbatim; audit records above carry classification
metadata, never operation payload contents.

## Consequences

**Enables:** #7 (device registration/revocation) and #8 (session
expiry/rekey) already have most of their authorization‑adjacent surface
answered by ADR‑0002 directly; this ADR is what lets #13/#14 (adapters)
actually gate tool dispatch instead of trusting the client, and gives
#15/#16 (iOS clients) a concrete approval‑UI contract to build against
(§34's display fields, §3 above).

**Costs / follow-up work implied:**
- The terminal command risk‑classification table (§2) is explicitly not
  designed here — a maintainer‑defined policy list is needed before #53's
  requirements are actually implementable.
- The AgentBridge dispatcher that actually runs §1's five‑step chain
  doesn't exist yet — no host service exists at all (`docs/MIGRATION.md`:
  "It is a library, not a runnable service"). This ADR specifies the
  contract, not the code.
- Revoke‑scope/ownership (§4, Open Question #2) is unresolved and blocks
  a clean implementation of "Revoke All Devices" specifically.

**Risks if this ADR is wrong:**
- If ADR‑0002 or ADR‑0003 change materially during their own review
  (per the Status section's caveat), §1's dispatch ordering may need
  rework — most likely additive (a new step), not a redesign, since §1's
  ordering principle (authenticate → negotiate → authorize → approve →
  execute) is a fairly standard shape.
- If a future capability needs finer granularity than the LEVEL 0–5 scale
  provides (e.g. two LEVEL‑4 commands where one should be permitted and
  the other not, for the same device), the per‑operation classification
  table would need per‑command overrides layered on top of the level —
  a compatible extension, not a breaking change to `TrustedDevice`.

## Open questions for maintainer review

1. The terminal command risk‑classification table (§2) needs an actual
   maintainer‑defined policy — this ADR fixes the *mechanism*
   (classify, then gate by level, with destructive patterns escalating to
   LEVEL 5 + approval) but not the specific command list.
2. Revoke scope (§4) — can a connected device revoke only itself, or can
   some devices revoke others? The spec doesn't define an ownership/admin
   concept beyond a single‑user model; this ADR deliberately doesn't
   invent one.
3. Confirm the approval TTL default (5 minutes, §3) and single‑use
   semantics.
4. Confirm this ADR's reading of §35 — emergency controls skip the
   agent/event pipeline but not authorization itself — matches intent,
   since "must not depend on the AI responding" could alternatively be
   read as "must work even for an unauthenticated/unauthorized
   connection," which this ADR explicitly rejects as inconsistent with
   §33's "AgentBridge enforces it" for every action.
5. Confirm this ADR's dependency on ADR‑0002/ADR‑0003 landing close to
   their current drafted form (Status section) is an acceptable review
   order, versus waiting for those to merge first.

## References

- `docs/IOS-MASTER-SPEC.md` §23, §33–§35, §52–§55 (this repo) — the
  authorization scale, approval system, emergency controls, and
  file/terminal/audit requirements this ADR makes concrete.
- `docs/ADR/0002-post-pair-authentication.md` §3 (this repo) — the
  per‑operation‑enforcement and approvals‑as‑policy‑layer decisions this
  ADR inherits rather than re‑decides.
- `docs/ADR/0003-protocol-version-negotiation.md` §2 (this repo) — the
  capability‑negotiation layer this ADR's §1 sequences against, closing
  that ADR's open question #3.
- `docs/ADR/0004-agent-task-event-model.md` §4, §6 (this repo) — the
  `tool.*`/`approval.*` event shapes this ADR's approval flow is carried
  over.
- `host/AgentBridge/src/AgentBridge.Security/TrustRegistry.cs` (this
  repo) — `PermissionLevel`, `IsAuthorized`, `Revoke` — the existing
  implementation this ADR builds on unmodified.
