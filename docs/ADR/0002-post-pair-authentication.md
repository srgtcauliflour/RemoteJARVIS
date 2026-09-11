# ADR-0002: Post-Pairing Session Authentication, Device Trust Lifecycle, and Worker Isolation

## Status

**Proposed.** Not implemented. Per issue #5 this ADR requires maintainer/lead
review and explicit acceptance before any implementation work on #6
(Host capability authorization model), #7 (Device registration and
revocation), #8 (Session expiry and rekey), or the iOS session work (#15)
begins.

## Context

### What ADR-0001 already decided, and what it left open

`docs/MIGRATION.md` records that the snapshot's ADR-0001 "proposes TLS 1.3
mutual authentication, with fresh sessions and platform-protected persistent
identity," with status "explicitly proposed, not production-approved."
Issue #5 names the file this ADR follows up on as
`Documentation/ADR/0001-standard-session-transport.md` and lists the four
questions it leaves open: **native identity interoperability, expiry/
recovery, permissions, and worker-isolation.**

**Gap this ADR must flag rather than paper over:** ADR-0001's full text is
not present in this public repository. Per `docs/MIGRATION.md`'s exclusion
rules, `Documentation/` (the private original tree, distinct from this
repo's `docs/`) was never migrated publicly, and no `docs/ADR/` directory
exists here yet. This ADR was therefore written from the one public summary
of ADR-0001 in `docs/MIGRATION.md`, plus the actual shipped code described
below, plus `docs/IOS-MASTER-SPEC.md` (merged into this repo as the fuller
target architecture). **If ADR-0001's full original text imposes a
constraint not reflected in that summary, this ADR's decisions need to be
reconciled against it before acceptance — that reconciliation is explicitly
part of what "maintainer/lead review" means for this issue.**

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
  this is the value an iOS client would pin against, matching
  `IOS-MASTER-SPEC.md` §10's "host challenge → iPhone verifies trusted host
  key" flow.

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
  constant-time comparison.
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
traffic. `IOS-MASTER-SPEC.md` §12 is explicit that the session mechanism
must use established cryptographic primitives and must not invent
cryptography. This ADR's job is to make that shape concrete enough to
implement against the code above.

## Decision

### 1. Native identity interoperability

**Proposal:** the device side generates its long-term key pair in the
Secure Enclave as a non-exportable P-256 key (`SecureEnclave.P256.Signing.PrivateKey`
in CryptoKit) — the same curve `HostIdentityStore` already uses on the host
side, so both ends share one cryptographic family rather than needing two.

`TrustRegistry` already authenticates devices by X.509 certificate + EKU +
SHA-256 pin, not by raw public key. Rather than adding a second,
certificate-free device-identity path alongside it, this ADR proposes
keeping that shape and populating it at enrollment time: during the
Passkey-gated pairing transaction (§9 of the spec), the host issues a
short-lived client certificate wrapping the device's Secure Enclave public
key and enrolls it via `TrustRegistry.EnrollVerifiedDevice`. This reuses
the exact mechanism already implemented and reviewed, instead of building
a parallel trust store for iOS devices specifically.

**Routine (post-pairing) traffic does not redo this certificate exchange
and does not touch Passkey.** It proves possession of the already-enrolled
Secure Enclave private key through the session handshake below — signing
a handshake transcript, not presenting a certificate over TLS client-auth
on every reconnect.

**Concrete primitives** (per §12's "never invent cryptography," everything
below is a named, standard construction available in both platforms'
standard libraries — no custom crypto to design or review):

- Ephemeral key agreement: ECDH over P-256 (`ECDiffieHellman` in .NET,
  `P256.KeyAgreement` in CryptoKit).
- Key derivation: HKDF-SHA256 over the ECDH shared secret, salted with a
  transcript hash (protocol version, both ephemeral public keys, both
  long-term identities, a server-chosen nonce) to bind the session to this
  specific handshake and prevent replay/mix-up attacks.
- Mutual authentication of the exchange: both sides sign the handshake
  transcript with their existing long-term key (host's CNG ECDSA key,
  device's Secure Enclave key) — a signed-Diffie-Hellman / SIGMA-style
  pattern, the same family TLS 1.3 and the Noise Protocol Framework's
  `IK`/`XX` patterns use. This is what ADR-0001's "TLS 1.3 mutual
  authentication" intent becomes once TLS's own client-certificate
  machinery is replaced by an application-level handshake for the
  *routine* path (TLS/HTTPS is still expected to carry the transport
  itself; this is the identity layer riding on top of it).
- Session transport encryption: AES-256-GCM (`AesGcm` in .NET,
  `AES.GCM` in CryptoKit), keyed from the HKDF output.

### 2. Session expiry and rekey

**Proposal:** a session key is valid until the first of:

- a fixed TTL (proposed default: 12 hours — open to maintainer
  adjustment, not load-bearing to the design),
- an idle timeout (proposed default: 30 minutes with no traffic),
- a transport change (Wi-Fi ↔ cellular, per §75).

On any of these, per §18/§72–§75: **no Passkey prompt.** The device
performs a fresh handshake (§1 above) against its already-enrolled
identity and gets a new session key. This is true after app restart (§73),
host restart (§74), and network change (§75) — in every case the *existing*
long-term identities re-authenticate a *new* ephemeral session; nothing
about session expiry re-triggers pairing.

**Revocation propagation.** `TrustRegistry.Revoke` already fires
`DeviceRevoked` synchronously with the durable write. This ADR proposes
AgentBridge subscribe to that event and force-close any *live* session for
that device immediately, rather than only rejecting the device's *next*
handshake attempt — closing the gap where a revoked device could otherwise
stay connected on an already-established session until it happened to
expire or reconnect.

**Recovery is the one path that legitimately reintroduces Passkey**, per
§76: if the host's persistent identity is lost/rotated, or a device's
trust record is gone, there is no automatic re-trust. This ADR states it
as a hard requirement, not just descriptive text: **a missing or mismatched
long-term identity on either side MUST fail closed and require an explicit
fresh pairing; it must never fall back to trusting the new identity
automatically.**

### 3. Permissions

**Proposal:** keep the existing `PermissionLevel` enum as the single
source of truth (no second, parallel permission model for iOS). This ADR
records the 1:1 mapping to `IOS-MASTER-SPEC.md` §33 explicitly, since the
names differ slightly:

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

### 4. Worker isolation

This is the one area with no existing code to build on, so this ADR
proposes a direction rather than a committed design, and flags it as
needing its own follow-up rather than resolving it fully here:

- The process that actually executes remote commands/tool calls (the
  Claude Code / Codex adapters, terminal execution — issues #13, #14)
  should run as a separate OS process from AgentBridge's network-facing
  listener, communicating over a local, non-network IPC channel (a named
  pipe or Unix domain socket, chosen per-OS) rather than sharing an address
  space with anything parsing untrusted network input.
- The worker process should run with the least privilege the requested
  `PermissionLevel` allows where the OS makes that practical, rather than
  always inheriting full user privilege.
- **Open, explicitly unresolved by this ADR:** the concrete mechanism
  (Windows job objects / restricted tokens vs. another sandboxing
  approach) needs its own research spike before it's a committed design.
  This ADR proposes that worker isolation get a dedicated follow-up
  issue/ADR once #13/#14 (the adapters it would isolate) are further
  along, rather than blocking this ADR's acceptance on it.

## Consequences

**Enables:** #6, #7, #8, and the iOS session work in #15 all have a
concrete design to implement against instead of an open question each.
The existing `HostIdentityStore`/`TrustRegistry` code needs no breaking
changes — this ADR is additive (a pairing/enrollment flow calling
`EnrollVerifiedDevice`, a session-handshake layer sitting in front of the
existing authenticate/authorize calls, a revocation-event subscriber).

**Costs / follow-up work implied:**
- A new pairing/enrollment endpoint and QR-bootstrap flow (§8–§9 of the
  spec) — not yet designed in code, only in the spec's prose.
- A session-handshake and AEAD-transport implementation on both the host
  (.NET) and iOS (Swift/CryptoKit) sides — new code, though built entirely
  from standard-library primitives per the "never invent cryptography"
  rule.
- Worker isolation remains genuinely open; shipping #13/#14 without it
  would mean command/tool execution shares fate with the network listener
  in the interim — worth flagging to the maintainer as a sequencing
  question, not something this ADR silently defers past relevance.

**Risks if this ADR is wrong:**
- If the certificate-wrapping approach in §1 turns out to be awkward
  against `URLSession`/`Network.framework`'s actual client-certificate
  APIs once #15/#16 start real iOS implementation, the fallback is to
  authenticate the session handshake by raw public key instead and only
  keep `TrustRegistry`'s certificate shape as an internal representation
  the enrollment step synthesizes — a compatible fallback, not a redesign,
  but worth surfacing now in case it changes the maintainer's read on §1.

## Open questions for maintainer review

1. **ADR-0001's full text isn't available in this repo.** Please confirm
   nothing in it conflicts with the `docs/MIGRATION.md` summary this ADR
   was built from, and consider migrating a sanitized version of ADR-0001
   itself into `docs/ADR/0001-standard-session-transport.md` so future
   contributors aren't in the same position.
2. Session TTL / idle-timeout numbers in §2 are proposed defaults, not
   fixed — confirm or adjust.
3. Worker isolation (§4) is a direction, not a committed implementation —
   confirm this ADR should be accepted with that section explicitly
   marked as needing its own follow-up, rather than blocking on it.
4. The iOS Secure-Enclave-to-synthesized-X.509-certificate bridging
   approach in §1 needs validation against the real pairing implementation
   once #15/#16 begin — flagging now so it isn't assumed settled.

## References

- `docs/IOS-MASTER-SPEC.md` (this repo) — §5–§21 authentication
  architecture, §33–§34 authorization/approvals, §87–§88 security hierarchy
  and the absolute Passkey rule, §12 "never invent cryptography."
- `docs/ARCHITECTURE.md`, `docs/MIGRATION.md`, `AGENTS.md` §5, `SECURITY.md`
  (this repo).
- `host/AgentBridge/src/AgentBridge.Security/HostIdentityStore.cs`,
  `TrustRegistry.cs` (this repo) — the existing implementation this ADR
  builds on.
- ADR-0001, `Documentation/ADR/0001-standard-session-transport.md` —
  private/unpublished; summarized in `docs/MIGRATION.md`'s "Authentication
  remains unchanged" section. See open question 1 above.
