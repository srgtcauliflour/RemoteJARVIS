# RemoteJARVIS

RemoteJARVIS is a mobile-first remote interface for securely connecting to a developer-owned host machine and interacting with AI-assisted development workflows from iOS.

> Project status: migration / collaborative development setup.

## Goals

- Make secure first-time pairing straightforward.
- Keep routine authenticated traffic efficient after pairing.
- Separate the mobile client, host service, shared protocol, and integration layers.
- Make the project easy for human contributors and AI coding agents to work on in parallel.
- Keep `main` releasable and protected by review + CI.

## Repository map

```text
RemoteJARVIS/
├─ AGENTS.md                 # Canonical AI-agent instructions
├─ CLAUDE.md                 # Claude Code entrypoint -> AGENTS.md
├─ CONTRIBUTING.md           # Human contributor workflow
├─ SECURITY.md               # Security reporting + invariants
├─ docs/
│  ├─ ARCHITECTURE.md        # System boundaries and security model
│  ├─ ROADMAP.md             # Project phases
│  └─ DEVELOPMENT.md         # Local setup and collaboration model
├─ ios/                      # iOS client (move existing code here)
├─ host/                     # Host-machine service/daemon
├─ protocol/                 # Wire protocol/schema/shared contracts
├─ integrations/             # Codex/Claude/other integrations
├─ tests/                    # Cross-component and protocol tests
└─ .github/                  # PR, issue and CI configuration
```

The source directories above should be created/migrated as the existing project files are imported.

## Start contributing

1. Read `CONTRIBUTING.md`.
2. Read `AGENTS.md` if you use Codex, Claude Code, or another coding agent.
3. Choose an issue marked `good first issue`, `help wanted`, or a component label.
4. Comment that you are taking it before starting substantial work.
5. Fork the repository (recommended for community contributors) or create a branch if you have collaborator access.
6. Open a draft PR early.

## AI-assisted collaboration

RemoteJARVIS is deliberately structured for parallel AI development. Each task should have one owner, one branch/worktree, and a narrow file/component scope. Agents must not edit unrelated areas simply because they can.

See `AGENTS.md` and `docs/DEVELOPMENT.md`.

## Security

Do not put credentials, device pairing secrets, signing keys, private certificates, API keys, tokens, or production host details in the repository. Read `SECURITY.md` before changing authentication, pairing, transport, remote command execution, or secret storage.

## License

Choose and add a license before inviting broad public contributions. Apache-2.0 or MIT are common permissive choices; the project owner should make the final choice.
