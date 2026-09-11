<!--
Provenance: migrated verbatim from the private original project documentation
(`Documentation/ADR/0001-standard-session-transport.md`, excluded from
public migration per `docs/MIGRATION.md`'s "Excluded material" section).
`docs/MIGRATION.md` previously carried only a one-paragraph summary of this
document; this is the full original text, reviewed for anything requiring
redaction before publication (none was found — no credentials, keys,
hostnames/IPs, or personal data) and migrated here so `docs/ADR/0002-post-pair-authentication.md`
and future contributors have the actual decision record rather than a
summary. No wording below has been altered from the original.
-->

# ADR-0001: Prefer standard mutual TLS for post-pairing sessions

Status: **proposed; feasibility and independent review required**. Date: 2026-09-11.

Independent review completed: `0001-review.md`. The proposal is **not approved for production**. Native iPhone identity behavior, expired-certificate recovery, unconditional tool authorization and OS isolation remain unresolved feasibility gates.

## Context

The product requires first-pairing-only passkeys, separate persistent host/device identity, lightweight authenticated reconnect, ephemeral traffic keys, AEAD, forward secrecy, expiry, revocation and no invented cryptography. Windows is the initial host. No Apple SDK or signed iPhone app is currently available for interoperability tests.

## Proposed decision

Use TLS 1.3 with mutual certificate authentication for HTTPS/WebSocket after pairing. Let the system TLS implementation perform authenticated ephemeral exchange, HKDF and record AEAD. Prefer .NET/Kestrel on Windows so the server can use a CNG-backed certificate without exporting its permanent key to a plaintext PEM file. Preserve Python 3.12 for the existing agent/voice adapter in a separate private worker. On iOS evaluate URLSession client-certificate authentication with a Keychain SecIdentity and an additional trusted-host SPKI pin.

Pairing is a separately constrained HTTPS endpoint that cannot perform agent operations. Its invitation is created by a local host operator, expires quickly and can be consumed only once. Bind server-side passkey challenge state to the invitation, host, exact device certificate signing request and server-assigned scope; the client never chooses its own maximum scope. A verified CSR proves possession of the new device key. The pairing ceremony may register a first passkey or authenticate an existing account. It issues only a device certificate/trust record, not an ongoing bearer credential.

The first-owner invitation bootstraps account enrollment. Existing account enrollment must prove the authorized account rather than register an arbitrary new passkey. Later-device enrollment must not inherit administrative rights just because the user authenticated. The QR is a temporary enrollment capability and must not be logged or reused. Pin the host before disclosure. Host identity replacement requires an explicit fresh pairing, never silent acceptance.

Require peer certificate validation, certificate/key purpose, validity, exact trusted device mapping and current revocation status at connection establishment. Recheck the device's current authorization epoch on every action and close all its sessions immediately on revocation. A certificate alone is not authorization. Logical session IDs are bound to the socket/principal; they cannot be transferred to another connection.

V1 uses fresh full handshakes on reconnect/expiry. Disable TLS 0-RTT and application early data; do not add session resumption tickets until revocation behavior and platform support are demonstrated. A fresh mutual TLS handshake still satisfies lightweight reconnect without passkeys. The TLS stack owns traffic secrets; the application does not export or store them. WebRTC signalling uses this authenticated channel, while media uses standard DTLS/SRTP.

Logical session expiry must tear down the underlying transport and its authorized media/file streams before establishing a fresh TLS connection; changing an application ID on the old socket does not rotate transport keys. Revocation cancels all device-owned streams, pending approvals and queued work, with authorization rechecked at the final execution boundary. Media workers require a bounded independent authorization lease so a lost control connection cannot leave media running indefinitely.

Certificate validity is separate from persistent device trust. Renewal should normally happen proactively through the current authenticated session. A long-offline device may return after certificate expiry with its trusted key intact: it must not be forced into passkey pairing merely because the certificate expired. A potential renewal-only mTLS listener that validates the exact trusted device key while narrowly handling certificate time validity needs Schannel/iOS proof and independent review; it must grant no application operations and cannot weaken ordinary TLS validation. If no standard, implementable recovery path meets these constraints, reject this transport proposal before production implementation. Do not hide the problem with a longer certificate lifetime.

## Alternatives considered

| Approach | Assessment |
|---|---|
| Mutual TLS 1.3 with native key storage | Preferred existing protocol; native client identity and host key persistence require real-platform proof |
| TLS plus permanent bearer token | Does not meet the requested distinct device identity, replay and trust model |
| Bespoke signed ephemeral exchange/HKDF/AEAD envelope | Rejected: valid primitives do not make a new protocol reviewed cryptography |
| Noise via maintained audited implementations on both platforms | Possible fallback if native TLS identity constraints prevent mTLS; requires library/interoperability review |
| Python-only TLS boundary | Simpler host integration, but standard SSLContext loads private-key files; secure Windows key handling needs separate evidence |

## Required experiment

- Kestrel TLS 1.3 using a persistent non-exportable CNG ECDSA key under a least-privileged identity.
- Signed iPhone app generates a non-synchronizing device key, creates a CSR using reviewed code, receives a client certificate and establishes a URLSession WebSocket without repeated UI prompts.
- Inspect actual TLS version/key agreement; reject TLS 1.2 and early data. Exercise pin mismatch, invalid purpose/issuer, signature failure, expiry, policy change and active-session revocation.
- Certificate renewal uses the trusted device relationship and authenticated transport; an expired device certificate must have a documented safe renewal/recovery path. It must not be confused with a short-lived logical session expiring.
- Keep TLS termination at AgentBridge. Any future tunnel must preserve end-to-end host verification and client identity; forwarded certificate headers are not trusted client authentication.

No production listener or key material is created by this ADR.

## Sources

- [RFC 8446, TLS 1.3](https://www.rfc-editor.org/rfc/rfc8446)
- [Apple URLSession client certificate authentication](https://developer.apple.com/documentation/foundation/nsurlauthenticationmethodclientcertificate)
- [Kestrel endpoint and client certificate configuration](https://learn.microsoft.com/en-us/aspnet/core/fundamentals/servers/kestrel/endpoints?view=aspnetcore-10.0)
- [ASP.NET Core certificate authentication](https://learn.microsoft.com/en-us/aspnet/core/security/authentication/certauth?view=aspnetcore-10.0)
- [Microsoft CNG provider](https://learn.microsoft.com/en-us/dotnet/api/system.security.cryptography.cngprovider?view=net-10.0)
- [Python 3.12 SSLContext](https://docs.python.org/3.12/library/ssl.html)
