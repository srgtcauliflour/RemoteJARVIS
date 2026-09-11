# Contributing to RemoteJARVIS

Thanks for helping build RemoteJARVIS. The project is designed to support both human developers and AI coding agents without allowing parallel work to become chaotic.

## Before you start

- Read the project README and architecture docs.
- Search existing issues and pull requests.
- For non-trivial work, use an existing issue or open one before coding.
- For security-sensitive ideas, do not publish exploit details in a public issue; follow `SECURITY.md`.

## Community contribution model

Public/community contributors should normally use a fork and pull request. Maintainers and trusted collaborators may work in branches on the main repository.

Suggested flow:

```bash
git clone https://github.com/srgtcauliflour/RemoteJARVIS.git
cd RemoteJARVIS
git checkout -b feat/123-short-description
# make changes
git add -A
git commit -m "feat: short description"
git push -u origin feat/123-short-description
```

For multiple simultaneous AI tasks, prefer Git worktrees rather than multiple agents editing one checkout:

```bash
git fetch origin
git worktree add ../rj-123 -b feat/123-short-description origin/main
```

## Pull requests

- Keep PRs narrowly scoped.
- Open a draft PR early when work is substantial.
- Link the issue.
- Explain what changed, why, how it was tested, and any security impact.
- Expect review for architecture, authentication, protocol, storage, remote execution, and CI changes.

## Commit style

Use clear conventional prefixes when practical: `feat:`, `fix:`, `docs:`, `test:`, `refactor:`, `build:`, `ci:`.

## AI-generated contributions

AI-assisted contributions are welcome. The contributor remains responsible for the submitted code. Review generated code, run tests, and disclose important assumptions in the PR. Do not submit large unexplained generated diffs.

## Good first contributions

Great starting areas include documentation, UI accessibility, tests, mocks, fixtures, developer tooling, and isolated bugs labelled `good first issue`.
