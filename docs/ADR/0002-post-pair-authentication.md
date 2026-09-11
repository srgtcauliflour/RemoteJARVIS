# ADR-0002: Post-Pairing Session Authentication, Device Trust Lifecycle, and Worker Isolation

## Status

**Proposed.** Not implemented. Per issue #5 this ADR requires maintainer/lead
review and explicit acceptance before any implementation work on #6
(Host capability authorization model), #7 (Device registration and
revocation), #8 (Session expiry and rekey), or the iOS session work (#15)
begins.

**Revision note:** this ADR was originally drafted before ADR-0001's full
text was available in this repository, from only `docs/MIGRATION.md`'s
one-paragraph summary. `docs/ADR/0001-standard-session-transport.md` and
its independent review, `docs/ADR/0001-review.md`, have since been migrated
into the repo in full. That text directly conflicts with this ADR's
original §1 (see below), so this revision withdraws the original proposal
for routine-session authentication and replaces it with a design that
defers to ADR-0001's actual, already-reviewed decision. Nothing else in
this ADR was affected by the reconciliation.

## Context

### What ADR-0001 already decided, and what its review found

`docs/ADR/0001-standard-session-transport.md` (status: proposed, feasibility
and independent review required) decides that post-pairing sessions use
**TLS 1.3 with mutual certificate authentication**, with the platform TLS
stack — not application code — performing the authenticated ephemeral key
exchange, HKDF, and record-level AEAD. On Windows it prefers Kestrel with a
CNG-backed non-exportable certificate; on iOS it proposes `URLSession`
client-certificate authentication backed by a Keychain `SecIdentity`, plus
an additional trusted-host SPKI pin. Pairing is a separate, constrained,
single-use endpoint: a host-operator-issued invitation binds the passkey
challenge to the device's certificate signing request and a server-assigned
scope, and issues only a device certificate/trust record, never an ongoing
bearer credential. V1 uses fresh full TLS handshakes on every reconnect or
expiry, with 0-RTT/early data and session-resumption tickets explicitly
disabled. Certificate validity is explicitly separated from persistent
device trust, with a requirement that a device returning after its
certificate has expired — but whose trust record is still intact — must
not be forced back into passkey pairing.

Critically, ADR-0001's own "Alternatives considered" table evaluates and
**rejects** a "Bespoke signed ephemeral exchange/HKDF/AEAD envelope," with
the stated reasoning: *"valid primitives do not make a new protocol
reviewed cryptography."* Mutual TLS 1.3 with native key storage is instead
recorded as the preferred approach, pending real-platform proof of native
client identity and host key persistence.

The independent review (`docs/ADR/0001-review.md`, classification T4)
disposition is **"proposal not approved for production; proceed with
isolated feasibility experiments."** It endorses the TLS 1.3
mutual-authentication direction as sound but identifies five unresolved
issues, four High severity and one Medium: (1) the proposed Claude Agent
SDK `can_use_tool` callback does not cover every tool — pre-approved tools,
hooks, and permission rules can bypass it under current SDK behavior; (2)
the private worker IPC boundary is not yet defined as an actual privilege
boundary (an IPC label alone does not isolate filesystem/credential
access); (3) certificate lifetime versus persistent device trust lacks an
executable recovery policy for the case of a device returning after
certificate expiry with its trust intact; (4) native device identity and
host trust (Secure Enclave key generation, CSR, Keychain `SecIdentity`
retrieval, real `URLSession` mTLS interoperability) remain unproven by any
real signed-app test; (5) transport/session enforcement points — forcing
TLS 1.3, rejecting early data, tearing down streams/media/pending work on
revocation — need concrete definition rather than being implied by the
prose.

**What this ADR reconciles:** the original draft of this ADR's §1 proposed
an application-level session-authentication handshake built from ECDH
P-256, HKDF-SHA256, and AES-256-GCM — exactly the shape of protocol
ADR-0001's alternatives table rejects. That was written without access to
ADR-0001's actual text and is withdrawn below. §2–§4 are revised to
incorporate the independent review's more specific findings, which are
sharper than what this ADR originally sketched for session recovery and
worker isolation.

### What is already implemented (ground truth)

Two libraries already exist, unchanged in byte content since migration
(`docs/MIGRATION.md`), and this ADR is a proposal for how to *build on* them,
not replace them (per issue #5: "this ADR should build on that foundation
rather than propose a parallel mechanism"):

**`HostIdentityStore`** (`host/AgentBridge/src/AgentBridge.Security/HostIdentityStore.cs`,
Windows-only):
- Generates a non-exportable ECDSA P-256 key in Windows CNG
  (`CngExportPolicies.None`), wraps it in a self-signed certificate valid
  ~397 days, auto-renews when fewer than 30 days remain.
- Persists only the public certificate to `host.json`; the private key
  never leaves CNG. Storage directory is ACL'd to the current user + SYSTEM,
  writes are atomic, and reparse points are rejected on every path touched
  (defense against symlink-based storage attacks).
- Exposes a `Fingerprint` (SHA-256 of the exported SubjectPublicKeyInfo) —
  this is the value an iOS client pins against, matching both
  `IOS-MASTER-SPEC.md` §10's "host challenge → iPhone verifies trusted host
  key" flow and ADR-0001's "additional trusted-host SPKI pin."

**`TrustRegistry`** (`host/AgentBridge/src/AgentBridge.Security/TrustRegistry.cs`):
- `PermissionLevel` enum: `Observe, Chat, Operate, ModifyFiles,
  ExecuteCommands, Destructive` — already a near-exact match for
  `IOS-MASTER-SPEC.md` §33's LEVEL 0–5 model (Observe / Chat / Non-destructive
  operations / File modifications / Command execution /
  Destructive-system operations). This ADR treats that as confirmation the
  model is right, not a coincidence to re-derive.
- `TrustedDevice` record: `DeviceId`, `CertificateSha256`,
  `MaximumPermission`, `CreatedAt`, `RevokedAt`.
- `Authenticate(certificate, now)`: validates the certificate's validity
  window, requires the `clientAuth` EKU (OID `1.3.6.1.5.5.7.3.2`), and
  matches its SHA-256 against a registered, non-revoked device using a
  constant-time comparison — this is already, precisely, the mechanism
  ADR-0001's mutual-TLS decision needs at the application layer to map a
  validated peer certificate to a trust decision.
- `IsAuthorized(deviceId, requiredLevel)`: a separate, explicit check —
  authentication and authorization are already two different methods in
  the existing code, matching `IOS-MASTER-SPEC.md` §33's requirement that
  they stay separate.
- `Revoke(deviceId, now)`: persists the revocation durably *before*
  updating in-memory state, then raises a `DeviceRevoked` event.
- `EnrollVerifiedDevice(device)` is `internal` and documented as "No
  enrollment endpoint exists yet. Only a verified future pairing
  transaction may enroll." — this is the exact hook this ADR's pairing
  design needs to call.

### What the target architecture requires

`docs/IOS-MASTER-SPEC.md` (§5–§21, §87–§88, binding per `AGENTS.md` §5) and
`docs/ARCHITECTURE.md`'s trust lifecycle diagram already fix the shape:
Passkey authenticates **first pairing only** → persistent device/host trust
→ a lightweight cryptographically authenticated session handshake for every
subsequent connection → an AEAD-protected session carries WebSocket/WebRTC
traffic. `IOS-MASTER-SPEC.md` §12's requirement that the session mechanism
use established cryptographic primitives and never invent cryptography is
now doubly reinforced by ADR-0001's own rejection of a bespoke envelope for
the same reason. This ADR's job is to make that shape concrete enough to
implement against the code above, using the mechanism ADR-0001 already
selected.

## Decision

### 1. Native identity interoperability and session authentication

**Enrollment (unchanged from the original draft, and already compatible
with ADR-0001):** the device side generates its long-term key pair in the
Secure Enclave as a non-exportable P-256 key (`SecureEnclave.P256.Signing.PrivateKey`
in CryptoKit) — the same curve `HostIdentityStore` already uses on the host
side. During the Passkey-gated pairing transaction (§9 of the spec), the
device creates a CSR from that key; the host binds the CSR to the pairing
invitation and a server-assigned scope (per ADR-0001's pairing decision),
issues a client certificate, and enrolls it via
`TrustRegistry.EnrollVerifiedDevice`. This reuses the exact mechanism
already implemented and reviewed instead of building a parallel trust
store for iOS devices specifically, and it is exactly the shape ADR-0001's
pairing section describes: "a verified CSR proves possession of the new
device key."

**Routine (post-pairing) session authentication — revised to follow
ADR-0001, withdrawing this ADR's original proposal:** the original draft
proposed a custom application-level handshake (ephemeral ECDH P-256,
HKDF-SHA256 over a transcript hash, mutual transcript signatures, AES-256-GCM
transport) for every reconnect, reasoning that TLS's own client-certificate
machinery would be "replaced ... for the routine path." ADR-0001's
alternatives table rejects precisely this shape of proposal, and its
required-experiment list instead calls for real platform proof of native
mTLS. This ADR now adopts that decision directly: **every post-pairing
connection, including reconnect after session expiry, app restart, host
restart, or network change, is a fresh TLS 1.3 handshake with mutual
certificate authentication** — the iOS client presents its enrolled client
certificate through `URLSession`; the host (Kestrel) validates the peer
certificate's validity window, `clientAuth` EKU, and SHA-256 pin against
`TrustRegistry.Authenticate` (already implemented, unchanged) before
completing the WebSocket upgrade. TLS 0-RTT and application early data are
disabled, and no session-resumption tickets are used in v1, per ADR-0001.
The platform TLS stack performs the authenticated ephemeral exchange, key
derivation, and record AEAD that the withdrawn design tried to reimplement
at the application layer — there is no new cryptographic protocol to
design, implement, or get independently reviewed for this path. This does
not touch Passkey at any point after initial pairing.

This withdrawal is not a judgment that the original design's primitives
were unsound; ADR-0001's objection is about process, not the individual
primitives ("valid primitives do not make a new protocol reviewed
cryptography"), and this ADR accepts that reasoning rather than relitigate
it.

**Open feasibility gate, carried over from ADR-0001/its review (not
resolved by this ADR):** the independent review's finding #4 (High) is
that native Secure Enclave key generation, CSR creation, Keychain
`SecIdentity` retrieval, and real `URLSession` mTLS interoperability remain
unproven by any real signed-iPhone-app test — including which Keychain
accessibility class to use (`AfterFirstUnlockThisDeviceOnly` versus a
class that also demands user presence on every signature, which would
conflict with automatic reconnect) and whether the host pin identifies a
leaf SPKI or a trust anchor across certificate renewal. This ADR requires
that experiment be run, per ADR-0001's "Required experiment" section,
before #15/#16 (iOS session implementation) treat this section as settled.

### 2. Session expiry, rekey, and the certificate-versus-trust recovery gap

**Logical session lifetime (unchanged in substance):** a session is valid
until the first of a fixed TTL (proposed default: 12 hours — open to
maintainer adjustment, not load-bearing to the design), an idle timeout
(proposed default: 30 minutes with no traffic), or a transport change
(Wi-Fi ↔ cellular, per §75). On any of these, per §18/§72–§75, there is
**no Passkey prompt** — but where the original draft described this as
deriving "a new session key" from an application-level handshake, it is
now, concretely, **a fresh TLS 1.3 mutual-certificate handshake** (§1
above) against the device's already-enrolled certificate. This is true
after app restart (§73), host restart (§74), and network change (§75): in
every case the existing long-term identities re-authenticate a new
ephemeral TLS session; nothing about session expiry re-triggers pairing.

**Three distinct lifetimes must not be conflated (independent review
finding #3, High severity — this section is more specific than the
original draft's, which did not separate these):**
1. **Logical/application session expiry** — the TTL/idle/network-change
   rules above; this ADR's own proposal, freely adjustable.
2. **TLS client-certificate validity** — the enrolled device certificate's
   own expiry window (and, on the host side, `HostIdentityStore`'s ~397-day
   self-signed certificate with auto-renewal under 30 days remaining).
3. **Persistent device trust** — the `TrustRegistry.TrustedDevice` record,
   which is expected to outlive any single certificate.

**Requirement, stated as a hard constraint per the review:** a device
returning after (2) has lapsed while (3) is still intact must not be
forced into passkey re-pairing merely because its certificate expired.
Ordinary TLS validation will reject an expired client certificate outright,
so a plain mTLS handshake cannot itself serve that reconnect. ADR-0001
raises, but explicitly does not resolve, a possible narrowly-scoped
renewal-only listener that would validate the exact already-trusted device
key while handling only certificate-time-validity renewal, grant no
application operations, and not weaken ordinary TLS validation elsewhere —
and states that if no standard, implementable recovery path meeting those
constraints exists, the transport proposal should be rejected before
production implementation rather than papered over with a longer
certificate lifetime. **This ADR treats that recovery mechanism as
unresolved and required**, not as something either ADR-0001 or this ADR
has already designed: it must be prototyped (Schannel on the host side,
iOS's client-certificate stack on the device side) and independently
reviewed before v1, per the review's required fix/experiment for finding
#3. This ADR does not propose a specific mechanism for it.

**Revocation propagation (expanded per independent review finding #5,
Medium severity):** `TrustRegistry.Revoke` already fires `DeviceRevoked`
synchronously with the durable write. This ADR proposes AgentBridge
subscribe to that event and force-close, immediately: any live control
WebSocket for that device, any authorized file-transfer streams, any
WebRTC/media authorization, and any pending or queued execution for that
device — not only the control connection, since a revoked device that
keeps an open file stream or media session defeats the purpose of
revocation. Authorization must also be rechecked at the final execution
boundary, not only at connection establishment. Media workers require a
bounded, independent authorization lease so that a lost control connection
cannot leave media running indefinitely, per ADR-0001.

**Recovery is the one path that legitimately reintroduces Passkey**, per
§76: if the host's persistent identity is lost/rotated, or a device's
trust record is gone, there is no automatic re-trust. This ADR states it
as a hard requirement, not just descriptive text: a missing or mismatched
long-term identity on either side must fail closed and require an explicit
fresh pairing; it must never fall back to trusting the new identity
automatically.

### 3. Permissions

**Mapping (unchanged — this part of the original draft is unaffected by
the transport reconciliation):** keep the existing `PermissionLevel` enum
as the single source of truth (no second, parallel permission model for
iOS). This ADR records the 1:1 mapping to `IOS-MASTER-SPEC.md` §33
explicitly, since the names differ slightly:

| `PermissionLevel` (code) | Spec §33 level | Meaning |
|---|---|---|
| `Observe` | LEVEL 0 — Observe | read-only status/state |
| `Chat` | LEVEL 1 — Chat | conversational interaction |
| `Operate` | LEVEL 2 — Non-destructive operations | task control, non-destructive actions |
| `ModifyFiles` | LEVEL 3 — File modifications | write access to files |
| `ExecuteCommands` | LEVEL 4 — Command execution | terminal/process execution |
| `Destructive` | LEVEL 5 — Destructive/system operations | irreversible or system-level actions |

**Enforcement must be per-operation, not per-session.** `TrustRegistry.IsAuthorized`
already exists as a standalone check; this ADR requires AgentBridge call it
on *every* privileged operation dispatch, not once at session establishment
— a session must not front-load "this device may do X" and then trust the
client's own UI to gate everything for the rest of the session's life. This
mirrors `IOS-MASTER-SPEC.md` §33's "The iPhone UI does not enforce it
alone."

**Approvals are a policy layer on top of `PermissionLevel`, not a
replacement for it.** A device already authorized for `ExecuteCommands`
may still require an explicit per-action `Approval` object (§34) for
specific flagged operations (e.g. a destructive git operation, a delete).
`PermissionLevel` answers "is this class of action ever allowed for this
device"; approvals answer "is *this specific* action allowed *right now*."

**New: authorization-gate coverage for tool-execution adapters (independent
review finding #1, High severity — not resolved by this ADR, flagged for
#13/#14).** The `PermissionLevel`/`IsAuthorized` model above governs what
AgentBridge itself will dispatch, but for the Claude Code / Codex adapters
(#13, #14) it is not sufficient to rely on the Claude Agent SDK's
`can_use_tool` callback as a universal enforcement point. The independent
review found that current SDK behavior evaluates hooks, permission rules,
and modes *before* that callback runs, so pre-approved tools do not reach
it — loading existing agent configuration can import privileges even
without `bypassPermissions` explicitly set. This ADR requires whichever
issue implements the adapter to pick one complete enforcement path —
either bridge-owned capability tools with unsupported native tools
disabled, or a demonstrated mandatory OS-level interception path — rather
than relying on the callback alone, and to keep Claude identity/vault
storage separate from executable settings, hooks, MCP servers, and
permission grants. This ADR records the requirement; it does not resolve
it, since resolving it depends on #13/#14's actual adapter design.

### 4. Worker isolation

Replaced below with the independent review's more specific requirements
(finding #2, High severity); the original draft's sketch was directionally
right but underspecified:

- The process that actually executes remote commands/tool calls (the
  Claude Code / Codex adapters, terminal execution — issues #13, #14)
  runs as a separate OS process from AgentBridge's network-facing
  listener, communicating over a local, non-network IPC channel (a named
  pipe or Unix domain socket, chosen per-OS) rather than sharing an
  address space with anything parsing untrusted network input.
- **The bridge and worker's identities/tokens, filesystem ACLs, permitted
  network destinations, key ACLs, IPC peer checks, and allowed message
  types must all be explicitly recorded**, not left implicit. An IPC
  label or a second language does not by itself provide isolation: a
  worker running with the user's normal token can potentially reach the
  same files, local services, and key-use permissions as AgentBridge
  unless these are deliberately scoped down.
- Certificate issuance, device trust grants, approval records, and trust
  storage (`HostIdentityStore`, `TrustRegistry`) must stay inaccessible to
  the worker process entirely — the worker should have no path to the
  host's signing key or to `TrustRegistry`'s state.
- The broker (AgentBridge) must derive the acting principal/scope from its
  own authenticated session state, never from an identifier the worker
  supplies in an IPC message.
- **Before this section can be considered closed, the design must be
  proven, not just asserted:** demonstrate that an intentionally hostile
  or compromised worker process cannot use the host's signing key, modify
  `TrustRegistry`/policy state, call private desktop-control services, or
  access an unapproved filesystem root. Test resource-handle races at
  execution time and correct cancellation of descendant processes.
- **Open, explicitly unresolved:** how restricted Claude execution retains
  authorized memory/account access without copying credentials into logs
  or weakening account settings, and which concrete OS mechanism (Windows
  job objects / restricted tokens versus another sandboxing approach)
  should be used — Windows Job Objects provide process grouping, resource
  management, and termination, but the review is explicit that they must
  not be equated with filesystem or credential isolation.
- This ADR still proposes worker isolation get a dedicated follow-up
  issue/ADR once #13/#14 (the adapters it would isolate) are further
  along, rather than blocking this ADR's acceptance on it — but the bar
  that follow-up must clear is now the concrete list above, not an
  open-ended direction.

## Consequences

**Enables:** #6, #7, #8, and the iOS session work in #15 all have a
concrete design to implement against instead of an open question each.
The existing `HostIdentityStore`/`TrustRegistry` code needs no breaking
changes — this ADR is additive (a pairing/enrollment flow calling
`EnrollVerifiedDevice`, Kestrel mutual-TLS configuration sitting in front
of the existing authenticate/authorize calls, a revocation-event
subscriber).

**Costs / follow-up work implied:**
- A new pairing/enrollment endpoint and QR-bootstrap flow (§8–§9 of the
  spec) — not yet designed in code, only in the spec's prose.
- Kestrel TLS 1.3 mutual-certificate-authentication configuration on the
  host (client-cert validation wired to `TrustRegistry.Authenticate`,
  0-RTT/early data disabled, resumption tickets off) and `URLSession`
  client-certificate configuration on iOS, per ADR-0001's required
  experiment list. This is configuration and platform-integration work,
  not new cryptographic protocol design — but real platform proof of
  native certificate/Keychain behavior remains an open High-severity
  feasibility gate (independent review finding #4) until the required
  experiment is actually run.
- The certificate-expiry-vs-device-trust recovery mechanism (§2) remains
  genuinely open and is required before v1, per independent review
  finding #3 — this is new follow-up work this ADR does not resolve.
- Worker isolation remains genuinely open against the concrete bar in §4;
  shipping #13/#14 without it would mean command/tool execution shares
  fate with the network listener in the interim — worth flagging to the
  maintainer as a sequencing question, not something this ADR silently
  defers past relevance.

**Risks if this ADR is wrong:**
- If no standard, implementable recovery mechanism can be found for the
  certificate-expiry-vs-trust gap in §2, ADR-0001 itself says the
  transport proposal should be rejected before production implementation
  — since this ADR's session design depends entirely on ADR-0001's
  mechanism, that outcome would require revisiting this ADR as well, not
  just ADR-0001.
- If real-device testing (independent review finding #4) surfaces a
  Keychain/`URLSession` constraint that makes routine background
  reconnect via client-certificate mTLS impractical (for example, a
  locked-device accessibility class that would force a UI prompt on every
  handshake), the mutual-TLS design in §1 would need to be revisited
  against real platform behavior rather than assumed to work from
  documentation alone.

## Open questions for maintainer review

1. **Confirm the reconciliation direction taken in this revision** —
   deferring entirely to ADR-0001's TLS 1.3 mutual-certificate-
   authentication decision for routine session authentication, and
   withdrawing this ADR's original bespoke application-level handshake
   proposal — is correct, now that ADR-0001 and its independent review are
   both migrated into `docs/ADR/`.
2. Session TTL / idle-timeout numbers in §2 remain proposed defaults, not
   fixed — confirm or adjust. They now govern when a fresh mTLS handshake
   is required, not when a new symmetric key is derived at the
   application layer.
3. Worker isolation (§4) is now a concrete bar rather than an open
   direction, but is still a direction rather than a committed
   implementation — confirm this ADR should be accepted with that section
   explicitly marked as needing its own follow-up, rather than blocking
   on it.
4. The certificate-expiry-vs-device-trust recovery mechanism in §2 is
   explicitly unresolved by both ADR-0001 and this ADR (independent
   review finding #3, High severity) and blocks §2 from being a complete
   design. Should it get its own tracked follow-up issue/ADR now, or stay
   inside #8's scope until #8 is picked up?
5. Should independent review finding #1 (Claude Agent SDK `can_use_tool`
   callback coverage, §3 above) become its own tracked issue ahead of
   #13/#14, given it is a prerequisite for either adapter meeting §3's
   per-operation enforcement requirement?
6. The iOS Secure-Enclave-key/CSR/enrolled-certificate approach in §1
   needs validation against a real signed-app test (ADR-0001's "Required
   experiment," independent review finding #4) once #15/#16 begin —
   flagging now so it isn't assumed settled by this document alone.

## References

- `docs/ADR/0001-standard-session-transport.md` (this repo) — the transport
  decision this ADR builds on and now defers to for session
  authentication.
- `docs/ADR/0001-review.md` (this repo) — the independent review; findings
  #1, #2, #3, #4, and #5 are each addressed by name above.
- `docs/IOS-MASTER-SPEC.md` (this repo) — §5–§21 authentication
  architecture, §33–§34 authorization/approvals, §87–§88 security hierarchy
  and the absolute Passkey rule, §12 "never invent cryptography."
- `docs/ARCHITECTURE.md`, `docs/MIGRATION.md`, `AGENTS.md` §5, `SECURITY.md`
  (this repo).
- `host/AgentBridge/src/AgentBridge.Security/HostIdentityStore.cs`,
  `TrustRegistry.cs` (this repo) — the existing implementation this ADR
  builds on.
