# iOS client boundary

The audited source archive contains no Swift files, Xcode project/workspace, or Swift package. This directory reserves the established client boundary and does not represent an implemented app.

Passkeys are for first-time host pairing/trust establishment only. Routine reconnects and traffic must use efficient cryptographic authentication based on the established device/host trust. Native SDK, signing and interoperability work remain separate from source migration.

**Before writing any code in this directory, read `docs/IOS-MASTER-SPEC.md` in full.** It is the authoritative, binding build specification for the native iOS client, AgentCore, AgentBridge, the AgentBridge protocol, and the passkey-pairing/session-authentication security model summarized above. This applies to every contributor, human or AI.
