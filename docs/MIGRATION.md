# Source migration record

## Input and scope

Audited 2026-09-11. The owner confirmed the 490,467,803-byte `RemoteJARVIS.zip` prepared after excluding `.tools/` as the intended source.

SHA-256: `953abb1325256503305e0dbd01bf6aec921c6e8955fbd8356ba8fa31cc513ab3`.

Target scaffold: `srgtcauliflour/RemoteJARVIS`, `main` at `6dbf0441eea452a0fa0fa43c08bf53782dc0620f`. The scaffold already contains the collaboration contract, contribution/security documents, architecture/development/roadmap documents, ownership fallback and repository-health workflow. Keep them authoritative. The input `AGENTS.md` must not overwrite them.

The archive is an early host foundation: two .NET libraries, a standalone protocol-check source file, Windows local setup scripts, dependency-free Node readiness tooling, tests, design documents and third-party snapshots. It has no iOS source, executable AgentBridge service, pairing endpoint or first-party Codex/Claude adapter. Neither a full application nor authenticated end-to-end behavior is demonstrated.

## Placement preserving current behavior

| Archive source | Public destination | Reason |
|---|---|---|
| `AgentBridge/src/AgentBridge.Protocol/*` source/project files | `protocol/AgentBridge.Protocol/` | Shared protocol implementation, unchanged bytes. |
| `AgentBridge/src/AgentBridge.Security/*` source/project files | `host/AgentBridge/src/AgentBridge.Security/` | Windows host identity/trust foundation, unchanged bytes. |
| `AgentBridge/Directory.Build.props`, `AgentBridge/global.json` | Root files with the same names | Keeps both relocated libraries under the same original build settings and SDK pin. |
| `AgentBridge/tests/ProtocolChecks.cs` | `tests/protocol/ProtocolChecks.cs` | Existing cross-component check source; no runner supplied. |
| Root `scripts/`, `tests/`, `Configuration/`, `package.json` | Same relative paths | These scripts derive the project root from their location. Moving them now would redirect runtime/tool/config paths and break tests. |
| Upstream provenance | `Configuration/upstream.lock.json` | Records exact revisions and observed archive hashes; no vendored code. |
| `runtime/agent/backtalk/uv.lock` | `integrations/backtalk/uv.lock` | Reviewed dependency-resolution lock, absent from the upstream snapshot; retain unchanged to prevent re-resolution drift. |
| `Documentation/` | Hold original documents privately; migrate reviewed decisions into established `docs/` | Several status claims predate the C# files or initialized memory; raw source briefs include personal planning context. |
| Runtime settings | `Configuration/examples/*.example` | Same observed settings with placeholder paths; never loaded automatically. |
| No existing iOS or adapter source | `ios/README.md`, `integrations/README.md` | Records absent implementation without adding stubs. |

No existing C#, PowerShell, Node, Python, package or toolchain file is edited by the curated source import. File checksums make the relocations reviewable. New documentation, examples, provenance, attribution and publication checks are separate additions.

## Excluded material

Exclude the `runtime/` directory (29,990 files), `artifacts/`, `.tools/`, `.git/`, `.tmp/`, dependency environments and .NET `bin/obj`. The single reviewed runtime exception is the Backtalk lockfile, promoted to `integrations/backtalk/uv.lock`; no runtime tree is copied publicly. Do not copy an old repository's history, hooks or remote configuration. The smaller archive has no `.tools/` or `.git/`; the larger local backup does include them.

Runtime contains personalized absolute paths, generated Claude boot/memory pointers, an initialized memory vault and a Backtalk virtual environment. Preserve these privately for the existing installation. Do not copy them into a commit, release archive, CI artifact or public issue. The verification JSON and audio are local output; no audio listening or full binary review was part of the audit.

The source audit found no confirmed live credential, private key or Apple provisioning file in the reviewed first-party source. Automated matches in dependencies included parser markers, documentation tokens and version strings; the certificate file was a dependency CA bundle. This is not a guarantee about unreviewed binaries or external secure stores.

## Authentication remains unchanged

Passkeys are for initial host pairing/trust establishment only. Routine reconnect, session renewal and traffic must use efficient cryptographic authentication derived from the established host/device trust; no routine passkey prompts or permanent bearer-token shortcut is introduced.

The snapshot's ADR-0001 proposes TLS 1.3 mutual authentication, with fresh sessions and platform-protected persistent identity. Its status is explicitly proposed, not production-approved. The archive implements protocol validation, Windows CNG-backed host identity and certificate-based trust-registry logic, but no complete transport/pairing service. Preserve that distinction. Native identity interoperability, renewal/recovery, authorization and worker-isolation decisions remain separate reviewed tasks. The migration does not perform crypto or authentication redesign.

## Reproducing the source checks

Tools observed/required by the snapshot: Node >=24; Python 3.12 for Backtalk (development guard needs Python >=3.11); PowerShell on Windows; .NET SDK **10.0.401**, with roll-forward disabled. The archived portable-tool installer does not install Node or .NET. Retain its pinned uv/Git/Claude/eSpeak/Python versions and the pinned Backtalk language-model requirement. Do not use dependency upgrades to make migration checks pass.

From repository root:

```powershell
node --test tests/preflight.test.mjs
./tests/installer.Tests.ps1
./tests/host-scripts.Tests.ps1
./tests/memory.Tests.ps1
dotnet build protocol/AgentBridge.Protocol/AgentBridge.Protocol.csproj -c Release
dotnet build host/AgentBridge/src/AgentBridge.Security/AgentBridge.Security.csproj -c Release
```

The memory test needs the pinned ai-memory-vault source under ignored `upstream/source/`. Both .NET projects have no package references; an isolated NuGet configuration with no package feeds can be used for the baseline builds.

Audit results on an isolated copy before relocation:

- Node preflight tests: 7/7 passed.
- Installer lock/parser checks and staging/idempotence/WhatIf checks: passed.
- Memory initializer tests: 5/5 passed using private fixtures and pinned upstream templates.
- Protocol library: Release build passed with 0 warnings/errors on SDK 10.0.401.
- Security library: failed with existing CA1416 errors at `TrustRegistry.cs:35` and `:101`, where a broadly targeted class calls Windows-only helpers.
- Protocol checks: source present, but no test project/entry point; not run as an executable test suite.
- iOS, real pairing, remote transport, actual user-memory migration, microphone/live voice and authenticated Claude integration: not tested.

The mapped rehearsal reproduced the same test/build outcomes. The final import contains 26 copied source/lock/license files with manifest hashes. The combined scaffold/import index contains 57 files. Ignore-rule probes retained source/templates while excluding local output; a deliberately force-staged `.env` fixture was rejected.

The subsequent migration attempt resolved the build declaration and added the missing runner in separate commits; see the execution evidence below. The original import commit retains the exact input bytes and its original failure. Do not treat local test success as maintainer approval or a release baseline tag.

## Local runtime continuity

The safest import leaves the existing installation running from its original directory until cutover is tested. For a fresh checkout, restore the pinned upstream snapshots, install the recorded local tools, then use the existing staging script. Do not publish the source ZIP to help contributors restore dependencies; it contains private runtime material.

After fresh staging, copy the tracked `integrations/backtalk/uv.lock` into `runtime/agent/backtalk/uv.lock` before dependency synchronization, refusing to overwrite a different existing lock. Retain the pinned Backtalk language-model requirement as well. The upstream snapshot has no lockfile; staging it alone would lose the audited dependency resolution. Do not update the lock to fix migration failures. The lock covers the uv-resolved project; full parity of separately installed voice-model dependencies still requires a runtime check.

`Configuration/examples/README.md` records an important difference: the audited Backtalk config explicitly has `stt_device: cpu`, while the staging defaults omit it. Preserve that setting locally when reproducing the original runtime. A new checkout also changes absolute paths in several config/memory files. Update those privately and preserve all existing notes and preferences; never initialize over a user's vault. Virtual environments should be rebuilt at the new path from pinned locks, not transplanted.

## Publication checks

`.gitignore` is a convenience barrier, not a content scanner or history scrubber. Before any commit/push, stage only the reviewed import, run `python scripts/check-public-import.py`, review `git diff --cached --name-status` and the full staged diff locally, and run a dedicated secret scanner with redacted findings. The new repository-health step checks indexed content after checkout as defense in depth; a public CI run is too late to be the first secret review.

The guard reports paths/line numbers, rejects typical secret/state/build/archive paths and scans indexed text for high-confidence credential markers. It does not validate arbitrary binary assets, all token formats or Git history. Do not disable a finding to rush publication.

**License decision (2026-09-11):** the maintainer has chosen **AGPL-3.0-or-later** as the first-party project license, matching the license already used by the project's own runtime dependencies (fullstack-agent, Backtalk, ai-visualizer, barehands). The full text is at `LICENSE`. This does not relicense the adapted ai-memory-vault material: original memory-vault license text is retained under `LICENSES/`, and `NOTICE.migration.md` identifies the adaptation and records why the two licenses coexist in this repository. Distribution of the combined application, and acceptance of significant external contributions, should still get a maintainer re-review as the project grows.

## Migration execution evidence — 2026-09-11

The audited import was applied on branch `chore/import-current-source` in a fresh clone of the existing repository. The original source/archive and live installation remain unchanged.

Separate commits preserve review boundaries:

1. `f169883`: imports all 26 selected source/lock/license files with their original bytes and adds the reviewed repository support files.
2. `63d51a7`: changes only the Windows security project's target framework to `net10.0-windows` and updates its README. This accurately declares the existing CNG/Windows dependency; no authentication implementation or warning policy changes.
3. `769d78d`: adds an executable console harness for the existing unchanged protocol checks, plus test instructions. It fails if any check fails or no checks run.
4. Adds `LICENSE` (AGPL-3.0-or-later) and records the license decision in `NOTICE.migration.md` and here.

Current local results on Windows with .NET SDK 10.0.401 and Node 24.19.0:

- Security library and protocol/checks project: Release builds pass, zero warnings/errors.
- Existing protocol checks: 20/20 pass.
- Node preflight tests: 7/7 pass.
- Installer checks, host staging/idempotence/WhatIf suite and memory initializer suite: pass; memory has 5 passing cases.
- Dedicated Gitleaks 8.30.1 staged/history scans: no leaks found. The scanner was obtained from its official release and its archive SHA-256 verified against the published release digest.
- Indexed-file publication guard and scaffold validator: pass.

The archive's first-party C# implementation files, existing tests, scripts and dependency locks remain unchanged. The one imported project-file correction is visible separately from the frozen import. The draft still needs maintainer/CI review before merge. No iOS, live pairing, voice, Claude session or production remote service is claimed; no runtime cutover or release tag was performed.
