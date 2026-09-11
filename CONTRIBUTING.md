# Contributing to RemoteJARVIS

Thanks for helping build RemoteJARVIS. The project supports human developers and AI coding agents with one owner, issue, and branch/worktree per task.

## Before you start

Read [README.md](README.md), [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md), [docs/DEVELOPMENT.md](docs/DEVELOPMENT.md), and [SECURITY.md](SECURITY.md). Agents must also follow [AGENTS.md](AGENTS.md). Read the assigned issue and any component instructions; iOS, AgentBridge, protocol, or authentication/security work requires the full [iOS master specification](docs/IOS-MASTER-SPEC.md).

Search [open issues](https://github.com/srgtcauliflour/RemoteJARVIS/issues) for `good first issue` or `agent-friendly`, and check [pull requests](https://github.com/srgtcauliflour/RemoteJARVIS/pulls) for work already underway. Choose an unclaimed issue with no competing implementation, read its scope and dependencies, and comment that you are taking it before substantial work. For non-trivial work without an issue, open one first. Report sensitive vulnerabilities privately as described in `SECURITY.md`.

## Windows quick-start

This path verifies the imported host foundation on Windows; it does not set up a running remote service or an iOS app. Use a fresh checkout, not a live runtime or personal memory vault.

### 1. Install tools

Install these tools from their official sources and reopen **PowerShell 7** so they are on `PATH`:

- [Git for Windows](https://gitforwindows.org/).
- [PowerShell 7](https://learn.microsoft.com/en-us/powershell/scripting/install/installing-powershell-on-windows) (`pwsh`); Windows PowerShell 5.1 cannot run the memory suite correctly.
- [Node.js 24](https://nodejs.org/en/download); the verification script accepts Node >=24.
- [.NET SDK 10.0.401](https://dotnet.microsoft.com/en-us/download/dotnet/10.0), exactly as pinned in `global.json`; roll-forward is disabled.
- [Python 3.12](https://www.python.org/downloads/windows/), available as `python`; the readiness checks accept >=3.11 and <3.13. The portable runtime's separate Python pin is recorded in `Configuration/toolchain.lock.json`.

The existing portable-tool installer does not install Node or .NET. You do not need to install the full voice/Claude runtime or change dependency locks for this verification path.

```powershell
$PSVersionTable.PSVersion
git --version
node --version
dotnet --list-sdks
python --version
```

### 2. Clone and create an issue branch

Community contributors should [fork the repository](https://github.com/srgtcauliflour/RemoteJARVIS/fork), then copy their fork's HTTPS clone URL from **Code**. In PowerShell 7, from the directory that should contain your checkout:

```powershell
$forkUrl = Read-Host 'Paste your fork HTTPS clone URL'
git clone $forkUrl RemoteJARVIS
if ($LASTEXITCODE -ne 0) { throw 'Clone failed.' }
Set-Location RemoteJARVIS
git remote add upstream https://github.com/srgtcauliflour/RemoteJARVIS.git
git fetch upstream
if ($LASTEXITCODE -ne 0) { throw 'Fetch failed.' }
git switch -c docs/123-short-description upstream/main
if ($LASTEXITCODE -ne 0) { throw 'Branch creation failed.' }
```

Replace `123-short-description` with your issue number and scope, and choose a prefix such as `feat/`, `fix/`, `docs/`, or `test/`. Maintainers/trusted collaborators may clone the main repository instead and push an issue branch there; never push directly to `main`. The same `upstream` remote setup works for that route.

For a separate worktree, use the following **instead of** `git switch` above, with a unique branch and directory for each task:

```powershell
git worktree add ../rj-123 -b docs/123-short-description upstream/main
if ($LASTEXITCODE -ne 0) { throw 'Worktree creation failed.' }
Set-Location ../rj-123
```

Run the remaining commands from the checkout/worktree root. Root-level `scripts/`, `tests/`, and `Configuration/` intentionally retain their locations: the scripts derive the project root from their own path. See [docs/MIGRATION.md](docs/MIGRATION.md) before moving them.

### 3. Restore the pinned memory test fixture

A clean clone omits `upstream/source/`. The memory suite needs the ai-memory-vault license and templates at the path recorded in the lockfile. In your fresh checkout:

```powershell
$memory = (Get-Content ./Configuration/upstream.lock.json -Raw | ConvertFrom-Json).components |
    Where-Object name -EQ 'ai-memory-vault'
New-Item -ItemType Directory -Force ./upstream/source | Out-Null
git clone --no-checkout $memory.repository $memory.source_directory
if ($LASTEXITCODE -ne 0) { throw 'Memory source clone failed; use a fresh checkout or inspect the existing fixture.' }
git -C $memory.source_directory checkout --detach $memory.commit
if ($LASTEXITCODE -ne 0) { throw 'Pinned memory checkout failed.' }
```

This checks out the recorded Git commit, not the upstream default branch. The lockfile's archive SHA-256 applies to its archive download, not this Git checkout. Keep the source under ignored `upstream/`; do not stage it or copy private runtime data into the repository. If you use a new worktree, restore the fixture there too.

### 4. Run the build/test sequence

```powershell
pwsh ./scripts/Verify-Build.ps1
if ($LASTEXITCODE -ne 0) { throw 'Verification failed; review the per-step output.' }
```

Expect seven passing steps: Node preflight tests; installer, host-staging, and memory PowerShell suites; protocol and Windows security Release builds; and the protocol console harness (20 checks). The harness uses `dotnet run`, not `dotnet test`. The verifier reports missing prerequisites and runs every step, returning nonzero if any fails. See [tests/README.md](tests/README.md) for individual commands.

If the memory step fails on missing templates, check step 3. If .NET cannot select an SDK, install the exact `global.json` version. Passing this sequence does not demonstrate iOS, real pairing, remote transport, or live voice/Claude integration.

## Make, review, and publish the change

Keep changes within the issue scope. Add relevant tests and documentation, avoid generated build products and unrelated formatting, and rerun the affected checks. Update your branch from latest `upstream/main` before final review when practical, resolving conflicts and rechecking the result.

Before **every commit/push**, follow the [publication checks](docs/MIGRATION.md#publication-checks). Stage explicit reviewed files, then inspect the complete staged diff. For example, for a documentation-only change to this guide:

```powershell
git status --short
git add -- CONTRIBUTING.md
git diff --cached --name-status
git diff --cached
git diff --cached --check
python ./scripts/validate-repo.py
if ($LASTEXITCODE -ne 0) { throw 'Repository policy check failed.' }
python ./scripts/check-public-import.py
if ($LASTEXITCODE -ne 0) { throw 'Publication guard failed.' }
```

Use your actual changed filenames in `git add`. Run a dedicated secret scanner with redacted findings as well. For example, install [Gitleaks](https://github.com/gitleaks/gitleaks#installing) and scan the staged patch plus branch history before publication:

```powershell
gitleaks git --staged --redact .
if ($LASTEXITCODE -ne 0) { throw 'Staged secret scan failed.' }
gitleaks git --redact .
if ($LASTEXITCODE -ne 0) { throw 'History secret scan failed.' }
```

Resolve findings before proceeding; do not disable a finding to rush publication. After reviewing the diff and passing all relevant checks:

```powershell
git commit -m 'docs: describe contributor quick-start'
if ($LASTEXITCODE -ne 0) { throw 'Commit failed.' }
git push -u origin HEAD
if ($LASTEXITCODE -ne 0) { throw 'Push failed.' }
```

Use a commit message describing your change, with a conventional prefix when practical: `feat:`, `fix:`, `docs:`, `test:`, `refactor:`, `build:`, or `ci:`.

In the upstream repository's **Pull requests** page, choose **New pull request**, then **compare across forks** if needed. Set the base to `srgtcauliflour/RemoteJARVIS:main` and the head to your fork/issue branch. Review the comparison, fill in the PR template, and select **Create draft pull request** from the create-button dropdown. Open a draft early for substantial work. Explain the problem, change, tests, risks/security impact, and important assumptions; use `Closes #123` when the PR fully resolves that issue. Wait for required CI and maintainer review before merge, especially for architecture, authentication, protocol, storage, remote execution, and CI changes.

## What repository-health CI checks

The checks configured in [.github/workflows/repo-health.yml](.github/workflows/repo-health.yml) run on pull requests and pushes to `main`:

| Check | Actual coverage |
|---|---|
| `scripts/validate-repo.py` | Confirms eight required collaboration documents exist. Recursively searches the working tree, excluding `.git` paths, for files named exactly `.env`, `id_rsa`, or `id_ed25519`; even ignored/untracked matches can fail locally. It does not inspect their contents or build the code. |
| `scripts/check-public-import.py` | Reads **all indexed file versions**, not just changed files or unstaged working copies. Rejects excluded publication paths (runtime, tools, upstream source, environments, build products, secret-like files), non-regular/unmerged entries, files over 2,000,000 bytes, binary/non-UTF-8 content, and selected credential markers or personal absolute paths. Reports locations/reasons rather than matched secret values. |

Stage edits before the indexed guard so it checks the proposed content. CI sees the committed index after checkout; local review must happen before anything becomes public. These checks supplement the build/test sequence and dedicated secret scanning. They do not prove that all token formats, binary assets, or Git history are free of secrets, and `.gitignore` is not a scanner.

## AI-generated contributions

AI-assisted contributions are welcome. The contributor remains responsible for submitted code: review it, run tests, and disclose important assumptions in the PR. Do not submit large unexplained generated diffs. Follow the ownership and handoff rules in `AGENTS.md`; multiple agents must not intentionally edit the same files simultaneously.

Good starting areas include documentation, UI accessibility, tests, mocks, fixtures, developer tooling, and isolated bugs labelled `good first issue`.
