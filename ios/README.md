# iOS client boundary

The audited source archive contains no Swift files, Xcode project/workspace, or Swift package. This directory reserves the established client boundary and does not represent an implemented app.

Passkeys are for first-time host pairing/trust establishment only. Routine reconnects and traffic must use efficient cryptographic authentication based on the established device/host trust. Native SDK, signing and interoperability work remain separate from source migration.
