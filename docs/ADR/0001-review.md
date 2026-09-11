<!--
Provenance: migrated verbatim from the private original project documentation
(`Documentation/ADR/0001-review.md`, excluded from public migration per
`docs/MIGRATION.md`'s "Excluded material" section). This is the independent
review of `docs/ADR/0001-standard-session-transport.md`, reviewed for
anything requiring redaction before publication (none was found — no
credentials, keys, hostnames/IPs, or personal data) and migrated here so
`docs/ADR/0002-post-pair-authentication.md` and future contributors have
the actual review findings rather than a summary. No wording below has
been altered from the original.
-->

# ADR-0001 independent review

Date: 2026-09-11. Classification: T4. **Disposition: proposal not approved for production; proceed with isolated feasibility experiments.**

Scope: Architecture.md, ADR-0001, HOST-INTEGRATION-MAP.md, API-SOURCE-MANIFEST.md, and master §§5–20, 33–35, 71–76 and 88. This is an architecture review, not an implementation audit. No production bridge exists; no iPhone compilation, certificate interoperability or live Claude test was performed. The unresolved SDK/account/domain gates remain unresolved.

TLS 1.3 mutual authentication is a sound candidate for the required separation of long-lived identity and ephemeral traffic protection. The decision to avoid routine passkeys, bearer credentials and a bespoke encrypted envelope is appropriate. Full authenticated reconnect instead of resumption is permitted by master §17. The following issues must be resolved before adopting the architecture as an implementable security contract.

## 1. High: the proposed SDK callback does not cover every tool

The integration map's permission step 1 specifies SDK `default` plus `can_use_tool`. That combination does not establish the claimed universal gate: current SDK documentation evaluates hooks, permission rules and modes before calling the approval callback; pre-approved tools do not reach it. Loading existing agent configuration can therefore import privileges even without `bypassPermissions`. The map recognizes some bypasses but its prescribed fix remains insufficient. [SDK permission evaluation](https://code.claude.com/docs/en/agent-sdk/permissions), [Approval callback scope](https://code.claude.com/docs/en/agent-sdk/user-input).

**Required fix/experiment:** select one complete enforcement path: bridge-owned capability tools with unsupported native tools disabled, or a demonstrated mandatory interception path backed by OS restrictions. Preserve Claude identity and vault format separately from executable settings, hooks, MCP servers and permission grants. On the pinned SDK, exercise pre-approved reads/writes, project/user settings, hooks, subagents, alternate tools and cancellation. Every attempted operation must either produce a bridge policy decision for the exact action or be unable to execute. Callback-only tests cannot pass this gate. Live validation is blocked by the missing Claude account.

## 2. High: private worker IPC does not yet define a privilege boundary

A Python worker running with the user's normal token can potentially access the same files, local services and key-use permissions as AgentBridge. An IPC label or second language does not prevent that access. Job Objects provide process grouping/resource management and termination; the design must not equate them with filesystem or credential isolation. [Windows Job Objects](https://learn.microsoft.com/en-us/windows/win32/procthread/job-objects).

**Required fix/experiment:** record the bridge and worker identities/tokens, filesystem ACLs, permitted network destinations, key ACLs, IPC peer checks and allowed messages. Keep certificate issuance, device grants, approval records and trust storage inaccessible to the worker. Prove an intentionally hostile worker cannot use the host key, modify policy, call private desktop-control services or access an unapproved root. The broker must derive principal/scope from its own session, not worker-supplied IDs. Test resource-handle races at execution, and cancellation of descendants. Resolve how restricted Claude execution retains authorized memory access and account access without copying credentials into logs or weakening account settings.

## 3. High: certificate lifetime and persistent trust lack an executable recovery policy

The ADR correctly distinguishes logical sessions from certificates but defers the key case: a phone returns after its client certificate expires while its device trust is still valid. An mTLS-only renewal endpoint cannot serve that phone if TLS rejects its credential first. Expiration of the host certificate or its issuing chain has an analogous availability effect. Routine expiry must not silently become a new passkey enrollment under master §§18 and 72.

**Required fix/experiment:** define issuer ownership, certificate profile/EKU/SAN, stable host identity versus renewable leaf certificate, validity/renewal windows, offline duration and clock handling. Select an independently reviewed recovery/enrollment mechanism that proves the still-trusted device key without granting general API access to invalid certificates. Do not globally disable certificate validity checks or invent a signed recovery exchange. If the chosen mechanism cannot preserve automatic recovery, escalate the requirement conflict rather than describing it as ordinary re-pairing. Test offline-past-expiry, interrupted renewal, overlapping old/new certificates, stale registry backup and concurrent revocation. Revocation must dominate both renewal and reconnect.

## 4. High feasibility gate: native device identity and host trust are not yet proven

Generating an EC key, issuing its certificate and retrieving the matching Keychain `SecIdentity` is a documented direction; it is not evidence that this app's URLSession WebSocket, key protection and background requirements interoperate. Apple DTS explicitly describes building an identity from a locally generated key and returned certificate, including an EC/Secure Enclave direction. Do not reject mTLS based on an assumed blanket Secure Enclave limitation. [Apple DTS identity guidance](https://developer.apple.com/forums/thread/797509).

Choose key accessibility explicitly. `AfterFirstUnlockThisDeviceOnly` prevents migration to another device and permits access after the first unlock, but cannot operate before that unlock after reboot. Requiring biometric/user-presence authorization for every signature would conflict with automatic reconnect. The intended locked-device behavior must be a product decision, not a hidden Keychain default. [Apple Keychain accessibility](https://developer.apple.com/documentation/security/ksecattraccessibleafterfirstunlockthisdeviceonly).

**Required experiment:** real signed iPhone app; non-synchronizing key; reviewed CSR encoding; certificate import and identity retrieval; verified server trust before disclosing the client identity; mTLS WebSocket; restart, lock, restore and reinstall cases. Define whether the host pin identifies a leaf SPKI or a trust anchor, how normal hostname/chain validation applies on LAN and remote paths, and how an unchanged host key survives certificate renewal. Reject cross-host client-certificate challenges and redirects. A CSR proves key possession, not independently the physical device's hardware provenance; do not advertise attestation without a separate verified mechanism.

## 5. Medium: transport/session rules need concrete enforcement points

TLS authenticates its handshake, while application capabilities and expiry remain bridge responsibilities. Renaming the logical session does not create new traffic keys. The ADR's expiry rule therefore needs actual transport replacement; revocation must also invalidate active file streams, media authorization and pending execution, not just close the WebSocket. [TLS 1.3, including handshake and early-data semantics](https://www.rfc-editor.org/rfc/rfc8446).

**Required experiment:** force TLS 1.3; require a mapped client identity before WebSocket upgrade; prove missing/invalid certificates fail; set and verify server resumption policy using the supported stack (`AllowTlsResume` is available); observe fresh full handshakes on expiry/reconnect and rejection of early data. Test protocol downgrade and stale queued actions. Specify whether a brief network loss permits ongoing media/tasks, with bounded teardown on expiry, lock and revocation. Bind DTLS fingerprints and media-session ownership through authenticated signalling. [Kestrel TLS configuration](https://learn.microsoft.com/en-us/aspnet/core/fundamentals/servers/kestrel/endpoints?view=aspnetcore-10.0), [AllowTlsResume](https://learn.microsoft.com/en-us/dotnet/api/system.net.security.sslserverauthenticationoptions.allowtlsresume?view=net-10.0).

## Runtime choice and next decision

The .NET boundary plus Python worker is **conditionally justified**, not inherently unnecessary: native Windows key use is a concrete reason for .NET, while preserving the inspected voice/Claude integration is a concrete reason for Python. Keep .NET limited to transport, trust, policy and supervision; avoid duplicating the adapter/domain model. CNG includes different providers, so record the actual provider/export policy rather than equating "CNG" with hardware protection. [CNG providers](https://learn.microsoft.com/en-us/dotnet/api/system.security.cryptography.cngprovider?view=net-10.0).

First run a local host-only probe for key persistence/access control, TLS configuration and authenticated IPC. Measure packaging and supervision cost before locking the runtime choice. A Python-only alternative must demonstrate equally acceptable Windows key handling; reduced language count alone does not settle that tradeoff. No public listener is needed for these experiments.

Passkey enrollment remains blocked on an owned RP/AASA boundary and signed-app setup already recorded in the source manifest. The invitation/CSR binding and account-versus-device distinction are good. Finalize whether the RP verifier resides on the host or at an associated service before implementing pairing; no domain or service should be invented for the personal release.

Approval requires updated lifecycle/enforcement decisions plus the above measured evidence and independent review of the resulting implementation. Documentation and host-only probes cannot close the native SDK or production release gates.
