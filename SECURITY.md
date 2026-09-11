# Security Policy

RemoteJARVIS connects a mobile device to a developer-controlled host and may expose high-impact capabilities. Security changes therefore receive stricter review than ordinary UI or documentation changes.

## Core security model

- First-time pairing establishes trust between a mobile client and a host.
- The passkey is used during first-time pairing/trust establishment only.
- Normal traffic uses an efficient cryptographic session/device authentication mechanism based on the established trust relationship.
- Transport must provide confidentiality and integrity.
- Remote operations must be authenticated and authorized.
- Sensitive key material belongs in platform secure storage, not configuration files or source code.

## Never commit

- API keys or access tokens
- private keys/certificates
- pairing secrets
- production hostnames/IPs tied to private infrastructure
- provisioning profiles containing secrets
- real user data
- `.env` files with secrets

## Reporting vulnerabilities

Until GitHub private vulnerability reporting is enabled, contact the maintainer privately rather than filing a public issue for vulnerabilities that could compromise hosts, credentials, devices, or users.

Maintainers should enable GitHub Security -> Private vulnerability reporting when the repository becomes public.

## High-risk areas requiring maintainer review

- pairing/authentication
- cryptography/key lifecycle
- network transport
- command execution/terminal access
- file transfer
- permissions/authorization
- secret storage
- agent/tool execution boundaries
