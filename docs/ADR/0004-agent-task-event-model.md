# ADR-0004: Agent and Task Event Model

## Status

**Proposed.** Not implemented. Per issue #12 this sits between the
transport/negotiation layer (#9 Protocol version negotiation, #10
Compatibility and error model) and any specific adapter or client (#13
Codex adapter, #14 Claude Code adapter, #15 iOS host and session
management, #16 iOS reconnection and state recovery) — issue #12 is
explicit that none of those four should build against ad‑hoc event
shapes once this lands, so this ADR needs sign‑off before #13–#16
implementation starts, the same way ADR‑0002/ADR‑0003 gate their
downstream issues.

## Context

### What issue #12 asks for

A shared, adapter‑agnostic message/event vocabulary for representing
agent activity over the protocol: task started/progress/complete/error,
streaming output, and cancellation at minimum, composing with the
existing envelope rather than inventing a parallel format.

### What the master spec already names — ground truth, not invented here

`docs/IOS-MASTER-SPEC.md` §24 ("PROTOCOL") lists an example event
catalogue (the spec's own words: "Example events," not stated as
exhaustive) that already includes, verbatim: `task.started`,
`task.progress`, `task.completed`, `task.failed`, `task.cancelled`;
`tool.started`, `tool.progress`, `tool.completed`, `tool.failed`;
`approval.required`, `approval.approved`, `approval.denied`,
`approval.cancelled`; `message.send`, `message.received`,
`message.stream`; and a bare `error`. This ADR adopts that lifecycle
vocabulary as given rather than re‑deriving it — the naming decision is
already made in the "Law" document; what's missing is the payload shape
and the composition rules around it, which is what issue #12 actually
asks for.

§22 places an `EventManager` inside `AgentCore` (the iOS-side service
layer) and §23 places "event bus" and "agent adapter" inside
`AgentBridge` (the host-side secure boundary) — so this ADR's vocabulary
is specifically the contract at that event-bus boundary between the two.
§79 names `FullstackAgentAdapter`'s responsibilities as including "task
monitoring" and "tool events" explicitly, confirming those two event
families are an adapter's job to emit against one shared shape, not
something each adapter (`#13`, `#14`) invents independently — exactly
the risk issue #12 flags ("ad-hoc event shapes").

One naming note: the spec's own envelope example in §24 writes
`messageID`; the already-implemented `ProtocolEnvelope.cs` in this repo
uses `messageId` (camelCase, matching its other fields). This ADR follows
the implemented code's casing, per issue #12's instruction to compose
with the *existing* envelope rather than the spec's illustrative one.

### Relationship to ADR-0003

`docs/ADR/0003-protocol-version-negotiation.md` (drafted, not yet opened
as a PR) proposes namespaced, independently‑versioned capability ids —
e.g. `"shell.exec"`, `"fs.write"`, `"agent.codex"` — exchanged in a
`session.hello`/`session.negotiated` handshake. This ADR reuses that
exact id format to name individual tools inside `tool.*` events, rather
than letting each adapter invent its own tool‑naming scheme. One
namespace then answers two questions: "can this connection use X" (ADR‑
0003) and "which X just ran, on which task" (this ADR).

## Decision

### 1. Two-level hierarchy: task → tool calls

A **task** is one agent‑invocation unit of work tracked end‑to‑end — a
chat turn, a build‑watch run, a background job — matching the `Task` App
Entity (§30) and the Long‑Running Task model (§50). A task may perform
zero or more **tool calls** while it runs, each independently tracked.
Every `task.*` event payload carries a required `taskId` (GUID); every
`tool.*` event additionally carries `toolCallId` (GUID) and `toolName`
(an ADR‑0003‑format capability id) alongside the `taskId` of the task it
belongs to.

Concurrent tasks are expected — a background build‑watch task running
alongside a foreground chat task is exactly the kind of scenario §49–50
and the widget/Live Activity sections describe. The envelope's own
`sequence` field (`ProtocolEnvelope.cs`, already implemented) is
**session‑wide**, not per‑task, so it orders all traffic on a connection
but does not by itself let a client separate two interleaved tasks'
events. `taskId` is how a client demultiplexes: group by `taskId` first,
then order within that group by the envelope's session sequence.

### 2. Task lifecycle — the spec's five `task.*` events, payload shapes only

No new lifecycle event names are introduced; this ADR only specifies
what each one carries:

- `task.started` — `{ taskId, taskType, requestId?, startedAt }`.
  `taskType` is an adapter‑agnostic string (e.g. `"chat"`, `"command"`,
  `"buildWatch"`), not an adapter‑specific value.
- `task.progress` — `{ taskId, state, percent?, statusText? }`, where
  `state` is one of `"running"` or `"awaitingApproval"`. Introducing
  `awaitingApproval` as an explicit, named state (rather than leaving
  clients to infer it from a separately arriving `approval.required`
  event) is a deliberate addition — it's what lets Dynamic Island and
  Live Activity (§42–43) render a distinct "waiting on you" visual
  without stitching two event streams together themselves.
- `task.completed` — `{ taskId, completedAt }`, plus a `result` object
  whose internal shape is intentionally left to the adapter/task type —
  this ADR only fixes the envelope-level contract, not every task type's
  result schema.
- `task.failed` — `{ taskId, errorCode, errorMessage, failedAt }`.
  `errorCode` is a placeholder string pending #10's error model (see
  Open Questions) — this ADR deliberately does not design a full error
  taxonomy here.
- `task.cancelled` — `{ taskId, cancelledAt, cancelledBy }`, where
  `cancelledBy` is `"user"`, `"host"`, or `"policy"` (e.g. a revoked
  device per ADR‑0002 §2 force‑closing in‑flight work).

### 3. Streaming output — one new event beyond the spec's example list: `task.output`

The spec's `message.stream` is conversational reply text; `tool.progress`
is structured per‑tool‑call status (e.g. "40% through this file write").
Neither is specified for **raw streamed output of a running task** — the
stdout of a watched build, for instance — which is explicitly in scope
per issue #12 ("streaming output"). This ADR proposes:

`task.output` — `{ taskId, chunk, chunkSequence, stream }`, where
`stream` is `"stdout"`, `"stderr"`, or `"agentText"` and `chunkSequence`
is a per‑task monotonic counter, independent of the envelope's
session‑wide `sequence`. The per‑task counter exists so a client can
detect a dropped or out‑of‑order chunk *for one task* without
cross‑referencing the whole session's numbering, which matters
specifically because §1 already establishes that multiple tasks'
chunks can interleave on one session.

This is flagged plainly as the one addition this ADR makes beyond the
spec's own catalogue in §24 — that catalogue calls itself "Example
events," not an exhaustive list, but given `docs/IOS-MASTER-SPEC.md`'s
status as binding "Law" per `AGENTS.md` §5, this ADR surfaces the
addition explicitly for maintainer confirmation (Open Questions #1)
rather than quietly extending it.

### 4. Tool-call sub-events — `task.*` siblings, not a parallel task type

`tool.started` / `tool.progress` / `tool.completed` / `tool.failed`, each
carrying `{ taskId, toolCallId, toolName }`, where `toolName` is a
capability id in ADR‑0003's namespaced format (§ "Relationship to
ADR‑0003" above). This ADR does **not** re‑validate `toolName` against
the negotiated capability set inside the event model itself — that
enforcement already happens before dispatch, per ADR‑0002 §3
(`TrustRegistry.IsAuthorized`) and ADR‑0003 §2 (capability negotiation).
A `tool.started` event naming a capability that was never negotiated
would indicate a bridge‑side bug elsewhere in the stack, not something
this event model needs to guard against a second time.

### 5. Cancellation — a request/response pair, using envelope fields that already exist

The client sends an envelope of a new inbound command type,
`task.cancel`, with `RequestId` set and `payload: { taskId }`; the host
acts on it and emits `task.cancelled` with `CorrelationId` set back to
that original `RequestId`. This uses `ProtocolEnvelope`'s already‑
implemented `RequestId`/`CorrelationId` fields exactly as they exist
today — no `ProtocolCodec.cs` change is needed, mirroring ADR‑0003's
same "additive, no codec change" posture.

If a cancel request loses the race against the task finishing on its
own, this ADR's decision is that the host does **not** synthesize a
`task.cancelled` for an already‑`completed`/`failed` task — it leaves
the task's real terminal state as the record of what happened, rather
than adding a fictitious cancellation to the event trail. This is called
out explicitly as a decision, not an oversight (Open Questions #4), since
a client that's actively waiting on cancellation confirmation needs to
know a "no‑op, already finished" outcome is possible.

### 6. Approval integration — composes with ADR-0002 §3, doesn't replace it

`approval.required` correlates to the task/tool that triggered it via
`{ taskId, toolCallId?, approvalId }`. Per §2 above, the task's own state
moves to `awaitingApproval` when this fires — the two events are
redundant by design, so a client that only watches task state still sees
the wait, and a client that renders a dedicated approvals list can key
off `approvalId` directly. `approval.approved` / `approval.denied` /
`approval.cancelled` carry the same `approvalId`; on approval the task
resumes (`task.progress` with `state: "running"`), on denial the task
moves to `task.failed` with a distinguishing `errorCode` (again, pending
#10). This composes with ADR‑0002 §3's "approvals are a policy layer on
top of `PermissionLevel`, not a replacement for it" — that ADR defines
*when* an approval is required; this one defines how that decision shows
up on the wire.

## Consequences

**Enables:** #13/#14 (adapters) and #15/#16 (iOS clients) get one shared,
versionable event vocabulary to build against instead of each inventing
its own shapes — directly the outcome issue #12 asks for.

**Costs / follow-up work implied:**
- `task.output` is new wire surface, not literally present in the spec's
  example catalogue — needs explicit sign‑off (Open Questions #1).
- `awaitingApproval` as a named `task.progress` state is likewise new
  and needs confirmation it's the right contract for the Dynamic
  Island/Live Activity UX described in §42–43.
- `task.failed`'s `errorCode` is a placeholder until #10 lands; once it
  does, this ADR's error payloads should be revisited to use whatever
  taxonomy #10 settles on rather than this ADR's ad‑hoc string.
- None of `task.*`/`tool.*`/`approval.*` handling is implemented
  anywhere yet — this ADR specifies the contract, not the code.

**Risks if this ADR is wrong:**
- If a future adapter needs a deeper hierarchy than task → tool call
  (e.g. a tool call that itself spawns sub‑tasks), the two‑level model
  in §1 would need a third level — a compatible extension (an optional
  `parentToolCallId` field), not a breaking change to what's specified
  here.
- If `chunkSequence` in §3 turns out unnecessary in practice (because
  clients always have enough context from `taskId` grouping alone), it's
  a harmless unused field, not a design flaw that blocks anything.

## Open questions for maintainer review

1. Confirm `task.output` (§3) as a new message type is acceptable — the
   one addition this ADR makes beyond the spec's own §24 example
   catalogue.
2. Confirm `awaitingApproval` as an explicit `task.progress` state (§2),
   rather than inferring it purely from a separately arriving
   `approval.required` event, is the right contract for Dynamic
   Island/Live Activity.
3. Confirm this ADR should leave `task.failed`'s `errorCode` as a
   placeholder and wait for #10 to define the real error taxonomy,
   rather than attempting to design that taxonomy here.
4. Confirm the §5 decision that a cancel request racing a task's natural
   completion produces no synthesized `task.cancelled` — versus always
   emitting some acknowledgement event, which has different tradeoffs
   for a client actively waiting on cancellation confirmation.

## References

- `docs/IOS-MASTER-SPEC.md` §22–24, §30, §42–43, §49–50, §79–80 (this
  repo) — the event names, AgentCore/AgentBridge boundary, and adapter
  responsibilities this ADR builds its payload shapes around.
- `docs/ADR/0002-post-pair-authentication.md` §3 (this repo) — the
  permissions/approvals foundation this ADR's approval integration
  composes with.
- `docs/ADR/0003-protocol-version-negotiation.md` (this repo) — the
  capability‑id namespace this ADR reuses for `toolName`.
- `protocol/AgentBridge.Protocol/ProtocolEnvelope.cs`,
  `ProtocolCodec.cs` (this repo) — the `RequestId`/`CorrelationId`
  fields this ADR's cancellation flow reuses unmodified.
