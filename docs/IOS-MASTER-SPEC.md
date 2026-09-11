# iOS / AgentBridge Master Specification

**Status: Authoritative.** This document is the canonical architecture and
build specification for the native iOS client, AgentBridge, the AgentBridge
protocol, and the passkey-pairing / session-authentication security model
referenced throughout `AGENTS.md`, `SECURITY.md`, `docs/ARCHITECTURE.md`,
and `ios/README.md`.

Any contributor — human or AI coding agent (Claude Code, Codex, or any
other) — doing iOS, AgentBridge, protocol, or authentication/security work
in this repository **must read this document in full before starting**,
and must treat its authentication architecture as a binding invariant, not
a suggestion or a starting point for redesign. In particular:

- Section 88, "PASSKEY RULE — ABSOLUTE," and Section 87, "SECURITY
  HIERARCHY," are load-bearing. Passkey/biometric confirmation is used
  **once**, to establish the initial trusted relationship between a device
  and a host. It is never used to authenticate ordinary reconnects, routine
  traffic, or (per the explicit correction in this document) privileged or
  destructive operations. Those are authorized through the trusted-device
  permission model, AgentBridge policy enforcement, and explicit approvals
  instead.
- Section 86, "NEVER FAKE FEATURES," and Section 39's "the model proposes,
  AgentCore decides, AgentBridge enforces" boundary apply to every PR that
  touches this surface: a mocked bridge, a static widget, or a compiled
  App Intent that doesn't reach the real architecture does not satisfy an
  issue derived from this spec.
- Section 12's prohibition on inventing cryptography is absolute: use
  established, current cryptographic libraries and primitives for the
  pairing handshake and session security; do not hand-roll key exchange,
  HMACs, or encryption.

`AGENTS.md` §5 ("RemoteJARVIS security invariants") is the short-form,
enforced summary of the rules in this document and requires an explicit
architecture/security issue plus maintainer approval to change. This
document is the full-form source those invariants are drawn from. Where a
later document in `docs/` records what was *actually* implemented for a
given phase, that document is the record of current behavior; this
specification remains the design contract implementations are measured
against. If the two conflict, raise it explicitly — in an issue or PR
description — rather than silently resolving the conflict in code either
direction.

This specification targets the still-unbuilt native iOS client and the
AgentBridge protocol/security layer described in `docs/ARCHITECTURE.md`'s
"iOS client (`ios/`)" and "Protocol (`protocol/`)" components. It does not
retroactively apply to, or require rewriting, the already-migrated
`AgentBridge.Protocol` / `AgentBridge.Security` .NET libraries beyond the
authentication invariants they already implement (see `docs/MIGRATION.md`).

**iOS 27 SDK currency is a standing requirement, not a one-time decision.**
Section 1 fixes iOS 27 / Xcode 27 as the minimum target, and Section 2 is
explicit that current Apple documentation and the current SDK are the
source of truth — not model memory, not this document's own prose where it
describes an API's shape. Every agent that touches iOS/AgentBridge platform
code must, before writing that code, verify the relevant API against the
Apple documentation and SDK version actually available at the time, and
must keep `docs/PLATFORM-API-MANIFEST.md` (this repo's equivalent of the
manifest Section 3 calls for) current: Xcode/SDK/Swift versions, API
availability, entitlements, deprecations, and any point where the shipping
SDK diverged from what this specification assumed. If the SDK and this
document disagree, the SDK wins per Section 2 — record the divergence in
the manifest and follow the current API; do not silently rewrite this
document's architecture to match, and do not silently implement the stale
assumption either.

One naming note for implementers: Sections 3 and 68 of the specification
below refer to a `Documentation/` tree (`Documentation/Platform/API-SOURCE-MANIFEST.md`,
`Documentation/Architecture.md`, etc.). In this repository `Documentation/`
already has a reserved meaning — it is the private, unpublished original
project documentation described in `docs/MIGRATION.md` and must never be
recreated or repurposed in the public tree. Wherever the specification
below says `Documentation/`, this repository uses `docs/` instead (e.g.
`docs/PLATFORM-API-MANIFEST.md`, `docs/Architecture.md` alongside the
existing `docs/ARCHITECTURE.md`). This is a path-naming substitution only;
it does not change any requirement, content, or intent of the specification.

Everything below this line is preserved verbatim as received from the
maintainer as the project's master build specification.

---

Yes. I would change the architecture more decisively:
Passkey is a one-time pairing/authentication mechanism, not an ongoing traffic-authentication mechanism and not a reauthentication mechanism for ordinary or privileged operations.
After the first successful pairing, the iPhone and AgentBridge should establish a persistent device-to-host trust relationship, then use a lightweight, cryptographically authenticated session mechanism for all subsequent traffic.
I would also remove the previous recommendation to use Passkey again for destructive operations. If your requirement is strictly Passkey once, at first host connection, then authorization for subsequent operations should be handled by the established device trust + efficient session credentials + AgentBridge permission system.
Below is the complete replacement master specification.
FULLSTACK AGENT FOR iOS 27
GOLD STANDARD MASTER BUILD PROMPT
GPT Astra 6 + Codex Autonomous Engineering Specification
Final Architecture — Passkey Pairing + Lightweight Cryptographic Session Authentication
 
⸻
 
0. MISSION
You are building an exceptionally advanced, production-quality, native iOS 27 AI assistant.
This is not:
	•	a mobile website
	•	a WebView
	•	a generic chatbot
	•	a remote desktop client
	•	an SSH client
	•	a thin API wrapper
	•	a collection of unrelated iOS features
The objective is to build a native iOS AI assistant whose primary intelligence resides on a user's computer through Jared Rhodenizer's fullstack-agent, while the iPhone becomes the primary human interface to that intelligence.
The central philosophy is:
The computer is the AI's body. The iPhone is the AI's human interface.
The finished system must feel like an AI assistant that is deeply integrated into iOS rather than an application that happens to communicate with another computer.
The application must exploit the maximum practical capability of:
	•	iOS 27
	•	Siri AI
	•	Apple Intelligence
	•	App Intents
	•	App Schemas
	•	App Entities
	•	Foundation Models
	•	Shortcuts
	•	ActivityKit
	•	Dynamic Island
	•	Live Activities
	•	WidgetKit
	•	Controls
	•	Visual Intelligence
	•	Spotlight
	•	notifications
	•	background execution
	•	modern networking
	•	WebRTC
	•	Passkeys
	•	Keychain
	•	modern cryptography
while respecting Apple's actual APIs, entitlements, security model and regional limitations.
 
⸻
 
1. ABSOLUTE PLATFORM REQUIREMENTS
Target:
	•	iOS 27 minimum
	•	current stable Xcode 27
	•	current iOS 27 SDK
	•	current supported Swift version
	•	SwiftUI
	•	Swift Concurrency
	•	App Intents
	•	ActivityKit
	•	WidgetKit
	•	Foundation Models
	•	AuthenticationServices
	•	Network framework
	•	AVFoundation
	•	WebRTC
	•	SwiftData
	•	Keychain
Do not support obsolete iOS versions.
Do not create unnecessary backwards-compatibility code.
Do not use deprecated APIs when current iOS 27 APIs exist.
 
⸻
 
2. CURRENT DOCUMENTATION IS THE SOURCE OF TRUTH
Before implementing platform-specific functionality, inspect the current Apple documentation and SDK.
Never rely exclusively on model memory for:
	•	Xcode 27
	•	iOS 27
	•	Swift 6.x
	•	App Intents
	•	App Schemas
	•	App Entities
	•	Siri AI
	•	Apple Intelligence
	•	Foundation Models
	•	ActivityKit
	•	Live Activities
	•	WidgetKit
	•	Controls
	•	Visual Intelligence
	•	Spotlight
	•	Passkeys
	•	AuthenticationServices
	•	Associated Domains
	•	background execution
	•	notifications
The implementation agent MUST inspect the latest available official Apple documentation and current SDK interfaces before implementing these systems.
Primary sources:
	•	Apple Developer Documentation
	•	Xcode 27 Release Notes
	•	iOS 27 Release Notes
	•	App Intents documentation
	•	App Intents updates
	•	App Schema documentation
	•	App Entity documentation
	•	Apple Intelligence documentation
	•	Foundation Models documentation
	•	ActivityKit documentation
	•	WidgetKit documentation
	•	AuthenticationServices documentation
	•	Passkey documentation
	•	Associated Domains documentation
	•	Visual Intelligence documentation
	•	Core Spotlight documentation
If the current SDK differs from examples found online:
the current SDK wins.
If an API has changed:
update the architecture to use the current API.
If a capability is unavailable:
do not fabricate it.
Document the limitation and preserve the architecture for future adoption.
 
⸻
 
3. PLATFORM SOURCE MANIFEST
Create:
Documentation/Platform/API-SOURCE-MANIFEST.md
Record:
	•	Xcode version
	•	SDK version
	•	Swift version
	•	minimum deployment target
	•	API versions
	•	API availability
	•	entitlements
	•	associated domains
	•	regional restrictions
	•	beta APIs
	•	deprecated APIs
	•	implementation decisions
	•	official Apple documentation references
Update it whenever platform assumptions change.
 
⸻
 
4. EXISTING HOST SYSTEM
The host system is:
https://github.com/jaredrhod/fullstack-agent
Treat this repository as the existing AI host environment.
The current system contains the components responsible for:
	•	persistent AI memory
	•	voice input/output
	•	visualizer
	•	optional webcam hand tracking
	•	Claude Code based agent operation
Do not unnecessarily rewrite those systems.
Do not replace Claude Code.
Do not replace the existing memory architecture.
Do not replace the existing voice architecture unless required for integration.
Do not destroy the existing visualizer.
Instead create a dedicated integration layer:
AgentBridge
Architecture:
                    iPHONE
                       │
        ┌──────────────┼──────────────┐
        │              │              │
      SwiftUI        Siri       Apple Intelligence
        │              │              │
        ├──────── App Intents ────────┤
        │              │              │
        ├────── App Schemas/Entities │
        │              │              │
        ├──────── Shortcuts ──────────┤
        ├──────── Widgets ────────────┤
        ├──────── Controls ───────────┤
        ├────── Dynamic Island ───────┤
        ├──── Live Activities ────────┤
        ├──── Visual Intelligence ────┤
        ├──── Foundation Models ──────┤
        │              │              │
        └────────── AgentCore ────────┘
                       │
                       │
                AgentBridge Protocol
                       │
              ┌────────┴────────┐
              │                 │
          WebSocket           WebRTC
              │                 │
              └────────┬────────┘
                       │
                  AgentBridge
                       │
                       ▼
                fullstack-agent
                       │
          ┌────────────┼────────────┐
          │            │            │
      Claude Code   Memory       Backtalk
                       │
                  Visualizer
The iPhone communicates with AgentBridge.
The iPhone does NOT directly depend upon fullstack-agent's internal implementation.
 
⸻
 
5. CRITICAL AUTHENTICATION ARCHITECTURE
PASSKEY IS A ONE-TIME PAIRING MECHANISM
This is a strict requirement.
Passkey MUST NOT be used for:
	•	every WebSocket message
	•	every WebRTC packet
	•	every API request
	•	routine reconnects
	•	ordinary conversation
	•	ordinary voice sessions
	•	ordinary task control
	•	routine privileged operations
	•	every application launch
Passkey is used to establish the initial trusted relationship between the iPhone and the host.
The intended flow is:
FIRST CONNECTION ONLY

Passkey
   ↓
User/device identity
   ↓
Host pairing
   ↓
Cryptographic device trust established
   ↓
Persistent trusted relationship
After this succeeds:
SUBSEQUENT CONNECTIONS

Trusted Device
      ↓
Host verification
      ↓
Lightweight session authentication
      ↓
Authenticated WebSocket
      ↓
Authenticated WebRTC
      ↓
Normal operation
The system must never repeatedly ask the user for Passkey authentication merely because the app reconnects.
 
⸻
 
6. PASSKEY'S EXACT ROLE
Passkey exists to solve:
"Who is allowed to establish the initial trusted relationship with this host?"
It does not solve:
"How do I authenticate every network packet?"
The network protocol solves that.
The AgentBridge session protocol must therefore have its own efficient cryptographic authentication.
 
⸻
 
7. TRUST ARCHITECTURE
The system contains five distinct concepts:
1. USER IDENTITY

Who is the user?

        ↓

2. DEVICE IDENTITY

Which iPhone is trusted?

        ↓

3. HOST IDENTITY

Which computer is trusted?

        ↓

4. SESSION IDENTITY

Which current connection is authenticated?

        ↓

5. AUTHORIZATION

What is this device allowed to do?
Never collapse these concepts into one bearer token.
 
⸻
 
8. INITIAL PAIRING
The first connection should be extremely simple.
Host
AgentBridge generates:
	•	Host ID
	•	persistent host key pair
	•	host fingerprint
	•	pairing nonce
	•	temporary pairing ID
The host displays a QR code.
The QR code contains only a short-lived bootstrap payload.
Example:
{
  "protocol": "agentbridge",
  "version": 1,
  "hostID": "...",
  "pairingID": "...",
  "hostPublicKey": "...",
  "endpoint": "...",
  "nonce": "...",
  "expiresAt": "..."
}
Never place inside the QR code:
	•	private keys
	•	passwords
	•	permanent API tokens
	•	permanent session tokens
	•	long-lived secrets
 
⸻
 
9. INITIAL IPHONE PAIRING
The iPhone scans the QR code.
The app:
	1.	Parses the bootstrap payload.
	2.	Validates its structure.
	3.	Checks expiration.
	4.	Verifies the host identity/fingerprint.
	5.	Connects to the temporary pairing endpoint.
	6.	Initiates Passkey authentication.
	7.	Establishes device identity.
	8.	Generates device cryptographic identity.
	9.	Sends the device public key to AgentBridge.
	10.	AgentBridge records the trusted device.
	11.	Both sides establish the permanent trust relationship.
	12.	Temporary pairing credentials are destroyed.
	13.	Normal session authentication begins.
The user should experience this as:
Scan QR
   ↓
Face ID / Passkey
   ↓
Connected
 
⸻
 
10. HOST IDENTITY
Every AgentBridge installation must generate a persistent cryptographic host identity.
It contains:
hostID
publicKey
privateKey
fingerprint
createdAt
softwareVersion
The private key MUST remain on the host.
The iPhone stores the trusted host public key.
When connecting:
iPhone
   ↓
Connection
   ↓
Host challenge
   ↓
AgentBridge signs challenge
   ↓
iPhone verifies trusted host key
   ↓
Host identity confirmed
This protects against host impersonation.
 
⸻
 
11. IPHONE DEVICE IDENTITY
During first pairing, generate a device identity.
The iPhone retains the private credential in secure storage.
Store:
deviceID
publicKey
deviceName
createdAt
lastSeen
trustStatus
permissionScope
The host stores the device public key.
The private key never leaves the iPhone.
 
⸻
 
12. POST-PAIRING TRAFFIC AUTHENTICATION
This is a critical design requirement.
After initial Passkey pairing, all normal network communication must use a lightweight cryptographic session mechanism.
Do NOT use Passkey assertions for normal traffic.
Do NOT perform an expensive authentication operation for every request.
Do NOT transmit permanent credentials with every request.
Use:
Trusted Device Key
        ↓
Authenticated Handshake
        ↓
Short-lived Session Key
        ↓
Authenticated Transport
The precise cryptographic implementation must be selected based on the strongest currently supported primitives available on both:
	•	iOS
	•	host operating system/runtime
The implementation agent must evaluate an appropriate modern authenticated key-exchange/session protocol rather than inventing cryptography.
Candidate approaches may include a modern ephemeral key exchange followed by authenticated key derivation and an AEAD-protected session.
The implementation MUST use established cryptographic primitives and libraries.
Never invent:
myOwnEncryption()
myOwnHMAC()
myOwnKeyExchange()
 
⸻
 
13. RECOMMENDED SESSION MODEL
Conceptually:
Trusted Device
       │
       │ device authentication
       ▼
Authenticated handshake
       │
       ├── nonce
       ├── ephemeral public key
       ├── device identity
       ├── host identity
       └── protocol version
       │
       ▼
Key agreement
       │
       ▼
Session key derivation
       │
       ▼
Authenticated encrypted session
Use an AEAD construction supported by the selected cryptographic library.
The session should have:
	•	session ID
	•	creation time
	•	expiry
	•	device ID
	•	host ID
	•	protocol version
	•	negotiated capabilities
	•	authorization scope
	•	replay protection
 
⸻
 
14. SESSION KEYS
Session keys should be ephemeral.
Do not use the permanent device key as the symmetric encryption key.
Do not use the host's permanent private key as a session key.
Use the trusted identities to authenticate the handshake.
Use ephemeral key material to establish the session.
Then:
Permanent identity
      ↓
Authenticates handshake

Ephemeral keys
      ↓
Establish session secret

Session key
      ↓
Protects realtime traffic
This provides:
	•	efficient traffic authentication
	•	confidentiality
	•	integrity
	•	replay resistance
	•	forward-secrecy properties where supported by the selected exchange
 
⸻
 
15. WEBSOCKET AUTHENTICATION
The WebSocket connection must be authenticated during the session establishment process.
After authentication:
iPhone
  ⇅
authenticated encrypted session
  ⇅
AgentBridge
Every protocol message must contain sufficient metadata for:
	•	correlation
	•	replay detection
	•	ordering where required
	•	session validation
Do NOT require a new Passkey assertion for every WebSocket message.
Do NOT attach a huge authentication structure to every event.
Use the authenticated encrypted transport/session.
 
⸻
 
16. WEBRTC AUTHENTICATION
WebRTC signalling must occur through the authenticated AgentBridge session.
The actual realtime media transport must use the security guarantees of WebRTC/DTLS/SRTP.
Do not implement custom encryption around individual audio packets unless technically required.
Architecture:
Passkey
  ↓
one-time trust

Trusted device
  ↓
authenticated AgentBridge session
  ↓
WebRTC signalling
  ↓
WebRTC secure media transport
  ↓
Realtime audio
This provides a much more efficient design than attempting to repeatedly authenticate individual voice packets.
 
⸻
 
17. SESSION RESUMPTION
When possible, support efficient session resumption.
Typical flow:
App launches
    ↓
Trusted host found
    ↓
Network available
    ↓
Session resume attempt
    ↓
Fresh cryptographic handshake/session
    ↓
Connected
Do not require Passkey.
Do not automatically reuse an expired session key.
Do not blindly trust a stale bearer token.
Use a secure session-resumption mechanism or perform a lightweight authenticated handshake using the established device identity.
 
⸻
 
18. SESSION EXPIRATION
Session credentials should expire.
However:
Session expiration must NOT mean Passkey authentication.
Instead:
Session expired
     ↓
New authenticated handshake
     ↓
New session key
     ↓
Continue
Passkey is only required if the trusted-device relationship itself has been removed, reset or intentionally re-paired.
 
⸻
 
19. DEVICE REVOCATION
If the user revokes an iPhone:
Host
 ↓
Remove device trust
 ↓
Invalidate active sessions
 ↓
Reject future handshakes
The iPhone must no longer be able to connect.
If the device is paired again:
perform the initial Passkey pairing flow again.
 
⸻
 
20. HOST REVOCATION
If the host trust record is deleted from the iPhone:
	•	remove host public key
	•	remove host metadata
	•	invalidate associated session credentials
	•	remove trusted state
Next connection requires:
fresh pairing.
 
⸻
 
21. NO PASSWORD-FIRST DESIGN
Do not create a conventional username/password login system unless an explicit recovery requirement demands it.
Preferred:
Passkey
+
device trust
+
cryptographic session
This is the identity model.
 
⸻
 
22. AGENTCORE
Create a single authoritative iOS service layer.
AgentCore
├── ConnectionManager
├── AuthenticationManager
├── PasskeyManager
├── DeviceTrustManager
├── HostTrustManager
├── SessionManager
├── AgentAPI
├── AudioManager
├── EventManager
├── IntentManager
├── PermissionManager
├── NotificationManager
├── ActivityManager
├── EntityManager
├── ShortcutManager
├── LocalIntelligence
├── ConversationManager
├── ProjectManager
├── FileManager
├── TerminalManager
└── DiagnosticsManager
Every interface must use AgentCore.
 
⸻
 
23. AGENTBRIDGE
AgentBridge is the secure boundary between the iPhone and fullstack-agent.
Responsibilities:
	•	host identity
	•	pairing
	•	passkey integration
	•	device trust
	•	session authentication
	•	authorization
	•	WebSocket
	•	WebRTC
	•	event bus
	•	voice bridge
	•	agent adapter
	•	project API
	•	memory API
	•	filesystem API
	•	terminal API
	•	diagnostics
	•	audit logging
The iPhone must NEVER communicate directly with unrestricted host internals.
 
⸻
 
24. PROTOCOL
Define a versioned protocol.
Example events:
agent.state
agent.status

session.started
session.ended
session.expired

message.send
message.received
message.stream

voice.started
voice.audio
voice.transcript
voice.interrupted
voice.speaking
voice.ended

tool.started
tool.progress
tool.completed
tool.failed

task.started
task.progress
task.completed
task.failed
task.cancelled

approval.required
approval.approved
approval.denied
approval.cancelled

host.status
host.metrics
host.offline

project.status
project.changed

memory.created
memory.updated
memory.deleted

file.changed

security.event

error
Every message:
{
  "protocolVersion": 1,
  "messageID": "...",
  "sessionID": "...",
  "timestamp": "...",
  "type": "...",
  "payload": {}
}
Support:
	•	version negotiation
	•	capability negotiation
	•	request IDs
	•	correlation IDs
	•	acknowledgements
	•	cancellation
	•	idempotency
	•	structured errors
	•	schema validation
 
⸻
 
25. CONNECTION STATE
Implement:
Disconnected
Connecting
Authenticating
VerifyingHost
Connected
Degraded
Reconnecting
Failed
Distinguish:
	•	no Internet
	•	host offline
	•	AgentBridge offline
	•	authentication failure
	•	host identity mismatch
	•	device revoked
	•	permission denied
	•	agent unavailable
 
⸻
 
26. MAIN APPLICATION
Native SwiftUI.
Navigation:
Home
Chat
Voice
Activity
Projects
Memory
Files
Terminal
Hosts
Settings
Home:
	•	agent identity
	•	host
	•	connection
	•	visualizer
	•	voice button
	•	current task
	•	conversation
	•	quick actions
 
⸻
 
27. NATIVE VISUALIZER
Implement a native iOS visualizer driven by AgentCore state.
States:
Idle
Connecting
Listening
Thinking
Speaking
Executing
Approval
Error
Offline
React to:
	•	microphone amplitude
	•	agent state
	•	speech
	•	task progress
	•	tool activity
Optimize rendering for battery.
 
⸻
 
28. REALTIME VOICE
Architecture:
iPhone microphone
      ↓
AVAudioSession
      ↓
audio engine
      ↓
WebRTC
      ↓
AgentBridge
      ↓
backtalk
      ↓
agent
Return:
agent voice
      ↓
AgentBridge
      ↓
WebRTC
      ↓
iOS audio
      ↓
speaker/AirPods/Bluetooth
Support:
	•	AirPods
	•	Bluetooth
	•	audio route changes
	•	interruptions
	•	background audio where permitted
	•	voice activity
	•	cancellation
	•	immediate interruption
 
⸻
 
29. VOICE INTERRUPTION
Mandatory.
If the agent is speaking:
User speaks.
Immediately:
voice detected
      ↓
cancel TTS
      ↓
stop playback
      ↓
switch to listening
The same cancellation path must be usable through:
	•	voice
	•	UI
	•	Siri
	•	Shortcut
	•	Dynamic Island
	•	Control
 
⸻
 
30. APP ENTITIES
Create structured entities:
Agent
Host
Device
Conversation
Message
VoiceSession
Task
Project
ProjectBranch
Commit
File
Process
Memory
Approval
Command
AgentEvent
Connection
Session
VoiceProfile
AudioOutput
Diagnostic
Build
These are semantic models for Siri/Apple Intelligence and app features.
Do not simply expose internal database records.
 
⸻
 
31. APP SCHEMAS
Use current iOS 27 App Schema capabilities wherever semantically appropriate.
The goal is for Siri/Apple Intelligence to understand:
	•	what an Agent is
	•	what a Host is
	•	what a Project is
	•	what a Task is
	•	what a Conversation is
	•	what an Approval is
	•	what a Memory is
and how they relate.
Use current supported mechanisms such as:
	•	RelevantEntities
	•	SyncableEntity
	•	EntityCollection
	•	ValueRepresentation
	•	rich parameter types
	•	current App Schema domains
where applicable.
Do not force unsupported schemas.
 
⸻
 
32. APP INTENTS
Implement a comprehensive catalogue.
Conversation
	•	Ask Agent
	•	Send Message
	•	Start Conversation
	•	Continue Conversation
	•	End Conversation
	•	Get Last Response
	•	Repeat Last Response
	•	Search Conversations
	•	Get Conversation
	•	Rename Conversation
	•	Delete Conversation
	•	Clear Conversation
	•	Switch Conversation
	•	Interrupt Agent
	•	Stop Agent Response
Voice
	•	Start Voice Session
	•	End Voice Session
	•	Pause Voice
	•	Resume Voice
	•	Toggle Voice Mode
	•	Enable Hands-Free
	•	Disable Hands-Free
	•	Enable Push-to-Talk
	•	Disable Push-to-Talk
	•	Mute
	•	Unmute
	•	Repeat
	•	Stop Speaking
	•	Change Voice
	•	Change Audio Output
	•	Set Volume
Agent
	•	Get Agent Status
	•	Get Agent State
	•	Start Agent
	•	Stop Agent
	•	Pause Agent
	•	Resume Agent
	•	Restart Agent
	•	Get Current Task
	•	Cancel Task
	•	Restart Task
	•	Reconnect Host
	•	Disconnect Host
	•	Lock Remote Control
Host
	•	List Hosts
	•	Connect Host
	•	Disconnect Host
	•	Get Host Status
	•	Wake Host
	•	Restart Host
	•	Shutdown Host
	•	Get CPU
	•	Get Memory
	•	Get Storage
	•	Get Network
	•	Get Diagnostics
Approval
	•	Get Pending Approvals
	•	Approve
	•	Deny
	•	Cancel Approval
	•	View Approval Details
Memory
	•	Remember This
	•	Search Memory
	•	Find Memory
	•	Add Memory
	•	Update Memory
	•	Delete Memory
	•	Forget This
	•	Summarize Memories
	•	Recent Memories
Projects
	•	List Projects
	•	Open Project
	•	Select Project
	•	Project Status
	•	Build Project
	•	Cancel Build
	•	Git Status
	•	Current Branch
	•	List Commits
	•	View Changes
	•	Summarize Changes
	•	Diagnose Project
	•	Fix Project
	•	Ask About Project
Files
	•	Find File
	•	Search Files
	•	Read File
	•	Create File
	•	Modify File
	•	Rename File
	•	Delete File
	•	Compare Files
	•	Search Project
	•	View Project Changes
Terminal
	•	Run Command
	•	Get Command Output
	•	List Processes
	•	Process Status
	•	Start Process
	•	Stop Process
	•	Restart Process
Security
	•	Authenticate
	•	Lock Remote Control
	•	Unlock Remote Control
	•	List Trusted Devices
	•	Revoke Device
	•	Revoke All Devices
	•	Verify Host
	•	Disconnect Host
	•	Emergency Stop
Security intents must enforce authorization server-side.
Do not use Passkey merely because an operation is privileged unless the current product requirements explicitly change.
 
⸻
 
33. AUTHORIZATION MODEL
Authentication and authorization are separate.
Authentication:
Is this a trusted device?
Authorization:
Is this device allowed to perform this action?
Use permission levels:
LEVEL 0
Observe

LEVEL 1
Chat

LEVEL 2
Non-destructive operations

LEVEL 3
File modifications

LEVEL 4
Command execution

LEVEL 5
Destructive/system operations
The trusted device has a maximum permission scope.
AgentBridge enforces it.
The iPhone UI does not enforce it alone.
 
⸻
 
34. APPROVAL SYSTEM
Create first-class approval objects.
Examples:
Modify source file?
Run command?
Delete file?
Reset repository?
Shutdown host?
Display:
	•	requested action
	•	target
	•	project
	•	risk
	•	explanation
	•	permission requirement
Use:
	•	Approve
	•	Deny
	•	Cancel
	•	Details
The server must verify that an approval is valid before executing it.
Never trust a forged client approval message.
 
⸻
 
35. EMERGENCY CONTROLS
Always provide:
	•	Stop Agent
	•	Disconnect Host
	•	Lock Remote Control
	•	Revoke Device
	•	Revoke All Devices
These must use the normal secure session.
They must not depend on the AI responding.
 
⸻
 
36. SHORTCUTS
Every appropriate App Intent should be usable in Shortcuts.
Provide:
Ask My Agent
Input:
	•	text
Output:
	•	agent response
Morning Briefing
Return:
	•	agent state
	•	overnight activity
	•	failed tasks
	•	approvals
	•	projects
	•	important events
Build Watcher
Monitor build.
Remember This
Send content to memory.
Project Health
Return:
	•	Git
	•	build
	•	failures
	•	pending work
	•	agent activity
Emergency Stop
Immediately stop active remote agent activity.
Agent as a Shortcut
Allow users to construct arbitrary workflows.
 
⸻
 
37. SIRI
Siri must be able to resolve meaningful application concepts.
Examples:
Ask my agent how the build is going.
What is my agent doing?
Stop the current task.
What failed?
Fix the build.
Tell my agent to remember this.
What did my agent remember about this project?
Open my project.
Start an agent voice session.
Use App Schemas/App Entities/App Intents as the semantic foundation.
Do not depend upon rigid phrases.
 
⸻
 
38. FOUNDATION MODELS
Foundation Models are the iOS-side intelligence layer.
They do not replace Claude.
Architecture:
Siri / Apple Intelligence
          ↓
     iOS Application
          ↓
   Foundation Models
          ↓
Local interpretation
          ↓
       AgentCore
          ↓
     AgentBridge
          ↓
 fullstack-agent
          ↓
       Claude
Potential local tasks:
	•	classification
	•	parameter extraction
	•	local summarization
	•	context compression
	•	routing
	•	privacy-sensitive preprocessing
	•	structured transformation
	•	local state explanation
 
⸻
 
39. FOUNDATION MODEL TOOLS
Possible local tools:
getConnectionStatus()
getCurrentAgent()
getCurrentTask()
getCurrentProject()
getRecentActivity()
getPendingApprovals()
sendAgentMessage()
startVoiceSession()
stopAgent()
getHostStatus()
Foundation Models must never bypass AgentCore.
The model proposes.
AgentCore decides.
AgentBridge enforces.
 
⸻
 
40. VISUAL INTELLIGENCE
Integrate with the current supported iOS 27 Visual Intelligence mechanisms.
Possible workflows:
Ask my agent about this.
Analyse this error.
Send this screenshot to my agent.
Explain this code.
What is wrong with this screen?
Use supported system APIs only.
Do not pretend the application has unrestricted access to the user's screen.
 
⸻
 
41. SPOTLIGHT
Index:
	•	Agents
	•	Hosts
	•	Projects
	•	Conversations
	•	Tasks
	•	Memories
	•	Files
Selecting results deep-links to the relevant screen.
 
⸻
 
42. DYNAMIC ISLAND
Dynamic Island is a core feature.
States:
Idle
Listening
Thinking
Speaking
Executing
Approval
Error
Offline
Compact:
● Agent
Expanded:
	•	agent
	•	state
	•	task
	•	progress
	•	elapsed time
	•	controls
Possible controls:
	•	Open
	•	Stop
	•	Mute
	•	Resume
	•	Approval
Use LiveActivityIntent where appropriate.
Security must still be enforced by AgentCore/AgentBridge.
 
⸻
 
43. LIVE ACTIVITY
Lifecycle:
Session Started
      ↓
Live Activity Started
      ↓
Listening
      ↓
Thinking
      ↓
Speaking
      ↓
Executing
      ↓
Idle
      ↓
Session Ended
Host-driven events can update the Live Activity through supported mechanisms such as ActivityKit/APNs.
 
⸻
 
44. LOCK SCREEN
Show useful live information:
Agent is thinking
Building Project
72%
or:
Build failed
Tap to inspect
Respect notification privacy.
 
⸻
 
45. WIDGETS
Create:
Agent Status
Current Task
Quick Ask
Approvals
Host Status
Emergency Stop
All interactive functionality should use App Intents.
 
⸻
 
46. CONTROLS
Expose appropriate Controls:
	•	Start Agent Voice
	•	Stop Agent
	•	Mute
	•	Connect Host
	•	Disconnect Host
	•	Emergency Stop
Sensitive operations remain permission controlled.
 
⸻
 
47. ACTION BUTTON
Where supported, provide App Shortcuts such as:
	•	Start Agent Voice
	•	Ask Agent
	•	Stop Agent
Do not assume all iPhones have an Action Button.
 
⸻
 
48. SIDE BUTTON
Architect for Apple's conversational app mechanisms where officially available.
Do not make the application dependent upon region-restricted capabilities.
Australia must remain fully functional without them.
If an entitlement/API is unavailable:
	•	do not fake it
	•	do not create an unsupported workaround
	•	preserve compatibility for future availability
 
⸻
 
49. BACKGROUND EXECUTION
Respect iOS limitations.
Use appropriate:
	•	audio background mode
	•	Live Activities
	•	APNs
	•	background tasks
	•	LongRunningIntent
	•	system-supported execution
Do not assume an unrestricted daemon can run inside iOS.
 
⸻
 
50. LONG-RUNNING TASKS
Use LongRunningIntent where appropriate.
Examples:
	•	monitoring a build
	•	synchronization
	•	long-running processing
	•	task monitoring
The actual computation happens on the host.
The iPhone monitors and controls it.
 
⸻
 
51. NOTIFICATIONS
Implement:
TASK_STARTED
TASK_PROGRESS
TASK_COMPLETED
TASK_FAILED
APPROVAL_REQUIRED
HOST_OFFLINE
HOST_ONLINE
CONNECTION_LOST
CONNECTION_RESTORED
AGENT_ERROR
SECURITY_EVENT
Each notification should deep-link to relevant state.
 
⸻
 
52. FILE SECURITY
AgentBridge must prevent:
	•	path traversal
	•	arbitrary root access
	•	symlink escapes
	•	unauthorized files
	•	oversized operations
Use canonicalized paths and permitted roots.
Never trust client-supplied paths.
 
⸻
 
53. TERMINAL SECURITY
Never expose an unrestricted Internet shell.
Implement:
	•	command policy
	•	project scope
	•	device permissions
	•	command risk classification
	•	rate limiting
	•	logging
	•	authorization
Do not rely upon the iOS app to enforce security.
The host must enforce it.
 
⸻
 
54. SECURITY TESTING
Mandatory tests:
Authentication
	•	expired session
	•	invalid session
	•	revoked device
	•	invalid device signature
	•	invalid host identity
	•	host impersonation
	•	QR replay
	•	expired QR
	•	pairing nonce reuse
	•	session replay
	•	handshake downgrade
	•	protocol mismatch
Network
	•	MITM
	•	malformed packets
	•	oversized messages
	•	message flooding
	•	WebSocket abuse
	•	WebRTC signalling abuse
Files
	•	../
	•	absolute paths
	•	symlinks
	•	permission escapes
	•	root escapes
Commands
	•	shell injection
	•	command injection
	•	privilege escalation
	•	argument injection
iOS
	•	malicious App Intent parameters
	•	malicious Siri parameters
	•	forged approval
	•	unauthorized Live Activity action
	•	revoked device
	•	stale device
	•	Keychain failure
 
⸻
 
55. SECURITY AUDITING
Log:
	•	pairing
	•	authentication
	•	device registration
	•	device revocation
	•	authorization failure
	•	privileged actions
	•	destructive actions
	•	emergency stop
	•	session creation
	•	session termination
	•	security violations
Never log:
	•	private keys
	•	passwords
	•	session secrets
	•	unnecessary conversation contents
 
⸻
 
56. SWIFTDATA
Use SwiftData for local state:
	•	conversations
	•	messages
	•	projects
	•	tasks
	•	hosts
	•	devices
	•	activity
	•	settings
	•	cached entities
Remote AgentBridge remains the source of truth for remote state.
 
⸻
 
57. KEYCHAIN
Store:
	•	trusted host public key
	•	device credentials
	•	session-resumption material where appropriate
	•	secure configuration
	•	sensitive state
Never store secrets in UserDefaults.
 
⸻
 
58. NETWORKING
Use:
	•	Network.framework
	•	URLSession
	•	WebSocket
	•	TLS
	•	WebRTC
	•	Swift concurrency
Use actors and Sendable where appropriate.
All networking must be concurrency safe.
 
⸻
 
59. ERROR MODEL
Implement structured errors:
notAuthenticated
authenticationExpired
hostNotTrusted
hostUnavailable
agentUnavailable
permissionDenied
approvalRequired
networkUnavailable
protocolMismatch
sessionExpired
invalidRequest
rateLimited
securityViolation
operationCancelled
agentError
Translate appropriately for:
	•	UI
	•	Siri
	•	Shortcuts
	•	notifications
	•	logs
 
⸻
 
60. OFFLINE
Differentiate:
No Internet
Host Offline
AgentBridge Offline
Session Expired
Host Not Trusted
Device Revoked
Agent Offline
Allow cached access to:
	•	recent conversations
	•	projects
	•	activity
	•	settings
Never falsely report online status.
 
⸻
 
61. MULTI-HOST
Support multiple trusted hosts architecturally.
Example:
Mac
Gaming PC
Home Server
Laptop
Each host has:
	•	unique identity
	•	public key
	•	capabilities
	•	connection
	•	permissions
	•	status
 
⸻
 
62. MULTI-DEVICE FUTURE
Architecture must allow:
	•	iPhone
	•	iPad
	•	Mac
	•	Apple Watch
	•	CarPlay
Do not implement these prematurely.
 
⸻
 
63. CONVERSATIONS
Support:
	•	streaming
	•	markdown
	•	code
	•	files
	•	images
	•	tool events
	•	approvals
	•	progress
	•	errors
	•	transcripts
Maintain semantic continuity between:
	•	app
	•	voice
	•	Siri
	•	Shortcuts
where Apple's APIs permit.
 
⸻
 
64. STATE MACHINE
Formal state machine:
Disconnected
     ↓
Connecting
     ↓
Authenticating
     ↓
VerifyingHost
     ↓
Connected
     ↓
Idle
     ↓
Listening
     ↓
Thinking
     ↓
Speaking
     ↓
Executing
     ↓
Idle
Other transitions:
Any State → Error
Any State → Disconnected
Executing → Approval
Approval → Executing
Executing → Cancelled
Speaking → Listening
This state drives:
	•	app
	•	visualizer
	•	Dynamic Island
	•	Live Activity
	•	widgets
	•	notifications
	•	accessibility
 
⸻
 
65. ACCESSIBILITY
Implement:
	•	VoiceOver
	•	Dynamic Type
	•	reduced motion
	•	high contrast
	•	accessibility actions
	•	state announcements
Do not communicate important state only through animation.
 
⸻
 
66. PERFORMANCE
Optimize:
	•	memory
	•	battery
	•	network traffic
	•	audio latency
	•	rendering
	•	connection latency
Use:
	•	event deltas
	•	IDs
	•	summaries
	•	incremental state
	•	compression where appropriate
Do not repeatedly transmit entire datasets.
Never sacrifice meaningful functionality merely to reduce token/network usage.
 
⸻
 
67. EFFICIENT AGENT CONTEXT
Use:
IDs
references
deltas
structured state
summaries
incremental events
instead of repeatedly sending:
	•	entire conversation
	•	entire project
	•	entire filesystem
	•	entire task history
Context compression is encouraged only when semantic information is preserved.
 
⸻
 
68. DOCUMENTATION
Create:
Documentation/
├── Architecture.md
├── Security.md
├── AgentBridge.md
├── Protocol.md
├── Authentication.md
├── Passkeys.md
├── DeviceTrust.md
├── HostTrust.md
├── SessionSecurity.md
├── AppIntents.md
├── AppSchemas.md
├── AppEntities.md
├── Siri.md
├── FoundationModels.md
├── VisualIntelligence.md
├── DynamicIsland.md
├── LiveActivities.md
├── Shortcuts.md
├── Widgets.md
├── Controls.md
├── BackgroundExecution.md
├── Audio.md
├── WebRTC.md
├── Testing.md
├── Deployment.md
├── Troubleshooting.md
├── RECONNAISSANCE.md
├── Platform/
│   └── API-SOURCE-MANIFEST.md
└── ADR/
 
⸻
 
69. PROJECT STRUCTURE
Use a scalable native structure:
FullstackAgent/
├── App/
├── Core/
│   ├── AgentCore/
│   ├── Networking/
│   ├── Authentication/
│   ├── Security/
│   ├── State/
│   └── Diagnostics/
├── Features/
│   ├── Home/
│   ├── Chat/
│   ├── Voice/
│   ├── Activity/
│   ├── Projects/
│   ├── Memory/
│   ├── Files/
│   ├── Terminal/
│   ├── Hosts/
│   └── Settings/
├── AppIntents/
├── AppEntities/
├── AppSchemas/
├── FoundationModels/
├── VisualIntelligence/
├── Widgets/
├── LiveActivities/
├── Controls/
├── Notifications/
├── Audio/
├── Persistence/
├── Security/
├── Resources/
├── Tests/
└── Documentation/
Use Swift Packages only when they provide meaningful separation.
 
⸻
 
70. ONBOARDING
First launch:
Welcome
   ↓
Connect Your AI Computer
   ↓
Add Host
   ↓
Scan QR
   ↓
Verify Host
   ↓
Passkey / Face ID
   ↓
Create Trusted Device
   ↓
Configure Permissions
   ↓
Test Connection
   ↓
Test Voice
   ↓
Complete
The user should not need to understand cryptography.
 
⸻
 
71. SET-AND-FORGET OPERATION
After first successful pairing:
Open app
   ↓
Discover known host
   ↓
Verify host identity
   ↓
Perform lightweight authenticated handshake
   ↓
Establish fresh session
   ↓
Connected
No Passkey prompt.
No password.
No QR scan.
No manual token entry.
No repeated pairing.
The experience should feel automatic.
 
⸻
 
72. WHAT HAPPENS IF THE SESSION EXPIRES?
Never show:
Please authenticate with Passkey again.
unless the trusted-device relationship itself is gone.
Instead:
Session expired
      ↓
New authenticated session handshake
      ↓
New session key
      ↓
Connected
 
⸻
 
73. WHAT HAPPENS IF THE IPHONE RESTARTS?
The trusted device identity remains stored securely.
On application launch:
Load trusted host
      ↓
Verify host
      ↓
Authenticate device
      ↓
Establish new session
      ↓
Connected
No Passkey.
 
⸻
 
74. WHAT HAPPENS IF THE HOST RESTARTS?
The host retains its persistent identity.
The iPhone reconnects.
The host proves its identity.
A new session is established.
No Passkey.
 
⸻
 
75. WHAT HAPPENS IF NETWORK CHANGES?
Example:
Wi-Fi
  ↓
5G
The connection manager should:
	1.	detect path change
	2.	terminate invalid transport
	3.	establish a new secure session
	4.	restore subscriptions
	5.	synchronize state
No Passkey.
 
⸻
 
76. WHAT HAPPENS IF TRUST IS LOST?
If:
	•	host key changes unexpectedly
	•	device trust is revoked
	•	pairing data is deleted
	•	security state is reset
then stop.
Do not automatically accept the new host.
Require:
explicit fresh pairing.
This may require Passkey again because this is a new trust relationship.
 
⸻
 
77. HOST INSTALLER
Build a host installer that:
	1.	Detects fullstack-agent.
	2.	Checks dependencies.
	3.	Installs AgentBridge.
	4.	Generates host identity.
	5.	Configures secure storage.
	6.	Configures networking.
	7.	Starts AgentBridge.
	8.	Generates pairing QR.
	9.	Waits for iPhone.
	10.	Performs initial pairing.
	11.	Confirms trusted device.
	12.	Starts normal operation.
Temporary pairing information must expire.
 
⸻
 
78. FULLSTACK-AGENT RECONNAISSANCE
Inspect actual source code for:
	•	startup
	•	shutdown
	•	Claude integration
	•	memory
	•	backtalk
	•	visualizer
	•	configuration
	•	processes
	•	logging
	•	permissions
	•	filesystem
	•	current communication mechanisms
Do not assume README descriptions are complete.
 
⸻
 
79. FULLSTACK AGENT ADAPTER
Implement:
FullstackAgentAdapter
Responsibilities:
	•	start
	•	stop
	•	send message
	•	receive response
	•	state
	•	task monitoring
	•	tool events
	•	memory
	•	projects
	•	permitted operations
	•	errors
Keep fullstack-agent-specific logic isolated.
 
⸻
 
80. CAPABILITY NEGOTIATION
AgentBridge should advertise capabilities.
Example:
{
  "protocolVersion": "1.0",
  "capabilities": [
    "voice",
    "tasks",
    "approvals",
    "projects",
    "memory",
    "files",
    "terminal"
  ]
}
The iPhone must adapt if a host lacks a capability.
 
⸻
 
81. DEVELOPMENT PHASES
Execute in this order.
 
⸻
 
PHASE 0 — RECONNAISSANCE
Inspect the complete host ecosystem.
Inspect current Apple APIs.
Inspect current Xcode 27 SDK.
Inspect security requirements.
Produce:
Documentation/RECONNAISSANCE.md
Do not begin major implementation until this is complete.
 
⸻
 
PHASE 1 — ARCHITECTURE
Define:
	•	module architecture
	•	data model
	•	AgentCore
	•	AgentBridge
	•	protocol
	•	state machine
	•	authentication
	•	passkey pairing
	•	device trust
	•	host trust
	•	session security
	•	permissions
Produce diagrams.
 
⸻
 
PHASE 2 — AGENTBRIDGE
Implement:
	•	host identity
	•	secure transport
	•	pairing
	•	protocol
	•	device trust
	•	session authentication
	•	permissions
	•	event system
	•	health checks
 
⸻
 
PHASE 3 — PASSKEY PAIRING
Implement:
	•	Associated Domains
	•	Passkey registration
	•	Passkey authentication
	•	pairing flow
	•	host verification
	•	device identity
	•	device trust
	•	QR bootstrap
	•	trust persistence
Then verify:
Passkey is NOT used for normal traffic.
 
⸻
 
PHASE 4 — SESSION SECURITY
Implement:
	•	authenticated handshake
	•	ephemeral session keys
	•	key derivation
	•	authenticated encryption
	•	replay protection
	•	session expiration
	•	session resumption
	•	device revocation
	•	host revocation
Use established cryptographic libraries/primitives.
Do not invent cryptography.
 
⸻
 
PHASE 5 — IOS FOUNDATION
Build:
	•	SwiftUI
	•	AgentCore
	•	networking
	•	Keychain
	•	SwiftData
	•	settings
	•	navigation
	•	error model
 
⸻
 
PHASE 6 — TEXT AGENT
Implement:
	•	chat
	•	streaming
	•	conversation
	•	task state
	•	cancellation
	•	errors
 
⸻
 
PHASE 7 — VOICE
Implement:
	•	AVAudioSession
	•	WebRTC
	•	realtime audio
	•	Bluetooth
	•	AirPods
	•	interruption
	•	background audio where permitted
 
⸻
 
PHASE 8 — VISUALIZER
Implement native visualizer.
 
⸻
 
PHASE 9 — APP ENTITIES
Implement all relevant entities.
 
⸻
 
PHASE 10 — APP SCHEMAS
Integrate current App Schema capabilities.
 
⸻
 
PHASE 11 — APP INTENTS
Implement the comprehensive intent catalogue.
 
⸻
 
PHASE 12 — SIRI
Test natural-language requests.
 
⸻
 
PHASE 13 — FOUNDATION MODELS
Implement local intelligence and tools.
 
⸻
 
PHASE 14 — SHORTCUTS
Implement the complete Shortcut catalogue.
 
⸻
 
PHASE 15 — DYNAMIC ISLAND
Implement:
	•	ActivityKit
	•	Live Activity
	•	visualizer
	•	progress
	•	controls
	•	Lock Screen
 
⸻
 
PHASE 16 — WIDGETS
Implement widgets.
 
⸻
 
PHASE 17 — CONTROLS
Implement system controls.
 
⸻
 
PHASE 18 — SPOTLIGHT
Index entities.
 
⸻
 
PHASE 19 — VISUAL INTELLIGENCE
Implement supported integrations.
 
⸻
 
PHASE 20 — BACKGROUND
Validate:
	•	audio
	•	Live Activities
	•	notifications
	•	background intents
	•	reconnect
 
⸻
 
PHASE 21 — SECURITY HARDENING
Run the complete security matrix.
 
⸻
 
PHASE 22 — PERFORMANCE
Measure and optimize.
 
⸻
 
PHASE 23 — POLISH
Complete:
	•	UI
	•	animation
	•	accessibility
	•	onboarding
	•	errors
	•	settings
	•	diagnostics
 
⸻
 
PHASE 24 — DOCUMENTATION
Complete all documentation.
 
⸻
 
PHASE 25 — RELEASE VALIDATION
Perform complete end-to-end validation.
 
⸻
 
82. TEST MATRIX
Verify:
Fresh installation
Fresh host
Fresh Passkey
Fresh pairing
Successful pairing
Failed Passkey
Cancelled Passkey
Invalid QR
Expired QR
QR replay
Host impersonation
Host key mismatch
Device revocation
Host revocation
Session expiration
Session renewal
App restart
iPhone restart
Host restart
Wi-Fi → cellular
Cellular → Wi-Fi
Internet loss
Host loss
Agent failure
WebSocket reconnect
WebRTC reconnect
Voice interruption
Backgrounding
Foregrounding
Dynamic Island
Lock Screen
Siri
Shortcuts
Widgets
Controls
Spotlight
Visual Intelligence
Approvals
Emergency Stop
 
⸻
 
83. DEFINITION OF DONE
The project is complete only when:
	1.	iOS 27 build succeeds.
	2.	AgentBridge builds.
	3.	Fullstack-agent integration works.
	4.	Host identity works.
	5.	QR pairing works.
	6.	Passkey first-time authentication works.
	7.	Trusted device works.
	8.	Host verification works.
	9.	Efficient post-pairing authentication works.
	10.	Passkey is NOT used for normal traffic.
	11.	Session keys are established securely.
	12.	WebSocket traffic is authenticated.
	13.	WebRTC signalling is authenticated.
	14.	WebRTC media uses its native secure transport.
	15.	Session expiry works.
	16.	Session renewal does not require Passkey.
	17.	Revocation works.
	18.	Text works.
	19.	Streaming works.
	20.	Voice works.
	21.	Voice interruption works.
	22.	Visualizer works.
	23.	Dynamic Island works.
	24.	Live Activity works.
	25.	Lock Screen works.
	26.	App Entities work.
	27.	App Schemas work.
	28.	App Intents work.
	29.	Siri integration works.
	30.	Foundation Models integration works.
	31.	Shortcuts work.
	32.	Widgets work.
	33.	Controls work.
	34.	Spotlight works.
	35.	Visual Intelligence integration works where supported.
	36.	Notifications work.
	37.	Approvals work.
	38.	Emergency stop works.
	39.	Offline mode works.
	40.	Reconnect works.
	41.	Security tests pass.
	42.	Performance is acceptable.
	43.	Accessibility is implemented.
	44.	Documentation is complete.
	45.	No critical security vulnerabilities remain.
 
⸻
 
84. AUTONOMOUS DEVELOPMENT RULES
The AI is expected to operate as the senior engineering team.
Do not repeatedly ask for permission to:
	•	create files
	•	refactor
	•	add tests
	•	add documentation
	•	improve architecture
	•	fix compiler errors
	•	fix tests
	•	add logging
	•	improve error handling
Before every major stage:
Inspect
Plan
Implement
Build
Test
Review
Document
Proceed
 
⸻
 
85. WHEN TO STOP AND ASK THE USER
Only stop for information that genuinely cannot be determined safely.
Examples:
	•	Apple Developer credentials
	•	signing certificates
	•	App Store configuration
	•	production domain
	•	production server credentials
	•	network configuration requiring user access
	•	irreversible production actions
	•	decisions that materially alter the security model
Do not stop for normal engineering decisions.
 
⸻
 
86. NEVER FAKE FEATURES
A feature is not complete because:
	•	a button exists
	•	an intent compiles
	•	Siri launches the app
	•	a widget shows static data
	•	Dynamic Island displays static animation
	•	a mocked AgentBridge responds
	•	voice playback is simulated
Every feature must connect to the actual architecture.
 
⸻
 
87. SECURITY HIERARCHY
The security architecture must be:
PASSKEY
   │
   │ one-time initial identity proof
   ▼
TRUSTED DEVICE
   │
   │ establishes persistent relationship
   ▼
HOST TRUST
   │
   │ confirms intended computer
   ▼
AUTHENTICATED SESSION HANDSHAKE
   │
   │ derives fresh session credentials
   ▼
SECURE SESSION
   │
   ├── WebSocket
   ├── HTTPS
   └── WebRTC signalling
        │
        ▼
    AgentBridge
        │
        ▼
   AUTHORIZATION
        │
        ▼
  fullstack-agent
This is the canonical security model.
 
⸻
 
88. PASSKEY RULE — ABSOLUTE
The following rule is mandatory:
Passkey is used only to establish the initial trusted relationship between the iPhone and AgentBridge.
Normal operation MUST NOT repeatedly invoke Passkey.
Normal traffic authentication MUST use an efficient cryptographically authenticated session mechanism.
If the trusted relationship is intentionally destroyed, the device is revoked, or the host is re-paired, the Passkey pairing flow may occur again.
Otherwise:
NO REPEATED PASSKEY PROMPTS.
 
⸻
 
89. INTELLIGENCE ARCHITECTURE
There are three intelligence layers:
Siri / Apple Intelligence
        ↓
iOS system-level intelligence

Foundation Models
        ↓
local application intelligence

Claude / fullstack-agent
        ↓
primary remote agent intelligence
Do not make them compete.
Use each where it provides the greatest value.
 
⸻
 
90. GOLD STANDARD UX
The intended experience:
User:
Hey Siri, ask my agent how the build is going.
Siri understands the Agent entity.
AgentBridge returns current build status.
User:
Tell it to stop if it fails.
The agent monitors the build.
The iPhone moves into the background.
Dynamic Island displays:
● Agent
Building…
The build fails.
Dynamic Island:
⚠ Build Failed
User taps it.
The application opens directly to the failure.
User:
Fix it.
The agent starts working.
Dynamic Island:
🔧 Fixing Build
████████░░ 82%
The user locks the phone.
The Live Activity remains visible.
The build succeeds.
Notification:
✓ Build Fixed
The user puts on AirPods.
What changed?
The agent answers.
User interrupts:
Stop.
Speech stops immediately.
Later:
What did we change yesterday?
The agent searches persistent memory.
This is the target experience.
 
⸻
 
91. FUTURE ROADMAP
Architect for:
Future A
Multi-agent support.
Future B
Apple Watch.
Future C
CarPlay.
Future D
iPad.
Future E
Mac companion.
Future F
Remote screen.
Future G
Keyboard/mouse.
Future H
Barehands integration.
Future I
Cross-device continuity.
Future J
Host-to-host orchestration.
Do not allow future compatibility to unnecessarily complicate version 1.
 
⸻
 
92. GOLD STANDARD PRINCIPLES
	1.	Native first.
	2.	iOS 27 first.
	3.	Siri first.
	4.	Apple Intelligence first.
	5.	Intent first.
	6.	Entity first.
	7.	Schema first.
	8.	Voice first.
	9.	Context aware.
	10.	Glanceable.
	11.	Automatable.
	12.	Passkey for initial pairing.
	13.	Lightweight cryptographic session authentication thereafter.
	14.	Host identity verification.
	15.	Device trust.
	16.	Authorization separate from authentication.
	17.	Security by default.
	18.	Privacy by default.
	19.	Structured protocol.
	20.	Efficient networking.
	21.	Graceful degradation.
	22.	No unnecessary duplication.
	23.	Current SDK only.
	24.	Test everything.
	25.	Document everything.
	26.	Never fake functionality.
	27.	Never invent cryptography.
	28.	Never expose unrestricted host capabilities.
	29.	Never sacrifice capability merely for convenience.
	30.	Optimize only where functionality remains identical.
	31.	Preserve future extensibility.
	32.	Make the computer the AI's body.
	33.	Make the iPhone the AI's human interface.
	34.	Make Siri understand the agent.
	35.	Make the entire system feel native to iOS.
 
⸻
 
93. FINAL DIRECTIVE
Build this system as one unified platform.
Do not think of the project as:
an iPhone app + a server.
Think of it as:
one AI assistant with a distributed architecture.
The computer provides:
	•	Claude
	•	compute
	•	tools
	•	files
	•	projects
	•	terminal
	•	persistent memory
	•	voice processing
	•	agent execution
The iPhone provides:
	•	identity
	•	voice
	•	display
	•	visualizer
	•	Siri
	•	Apple Intelligence
	•	App Intents
	•	Shortcuts
	•	Dynamic Island
	•	notifications
	•	contextual interaction
	•	mobility
	•	human interaction
The AgentBridge is the secure nervous system connecting them.
Passkey establishes the initial trust.
Cryptographically authenticated sessions provide efficient ongoing communication.
AgentCore is the authoritative iOS control plane.
AgentBridge is the authoritative host security boundary.
Claude/fullstack-agent remains the primary agent intelligence.
Apple Intelligence and Foundation Models make the system deeply native to iOS.
The final result should make the user feel that their AI is always available on their iPhone even though its primary computational body lives on their computer.
Build the Gold Standard.

The key change from the previous specification
The authentication lifecycle is now explicitly:
First pairing
QR → Passkey → device identity → host trust → persistent trust
Every normal connection thereafter
trusted device → host verification → lightweight cryptographic handshake → fresh session → WebSocket/WebRTC
Session expires
fresh lightweight handshake → new session
iPhone restarts
fresh lightweight handshake → new session
Host restarts
host identity verification → fresh lightweight handshake → new session
Wi-Fi → 5G
fresh lightweight handshake → new session
Device revoked / trust deleted
connection rejected → new Passkey pairing required
That is substantially cleaner than repeatedly invoking Passkeys, while still retaining a very strong security boundary. It also means the high-frequency traffic path remains efficient: the expensive identity operation happens once; the realtime system operates on an authenticated session.
One other deliberate change is that I have removed the previous "Passkey for dangerous operations" requirement. That was inconsistent with your clarified requirement. Authorization should instead be handled through the trusted-device permission model, AgentBridge policy enforcement, explicit approvals and secure session authentication. If you later decide you want biometric confirmation for a particular destructive operation, that can be added as a separate local user-presence policy without turning Passkey into the network authentication mechanism.
The final prompt is therefore ready to be handed to Astra 6/Codex as the project's master specification and autonomous implementation contract.
