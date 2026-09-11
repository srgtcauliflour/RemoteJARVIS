# Development and Collaboration

## Collaboration principle

GitHub is the durable source of truth. Discord is for conversation and recruitment, not for final architecture decisions or task ownership.

## Work ownership

Each active implementation task should have:
- a GitHub issue
- one owner
- one component label
- one branch/worktree
- a linked PR

This prevents human and AI contributors from editing the same subsystem blindly.

## Suggested labels

Component:
- `area:ios`
- `area:host`
- `area:protocol`
- `area:integration`
- `area:ci`
- `area:docs`

Type:
- `type:feature`
- `type:bug`
- `type:refactor`
- `type:test`
- `type:security`

Contributor:
- `good first issue`
- `help wanted`
- `needs design`
- `blocked`

AI coordination:
- `agent-friendly`
- `agent:lead-review`
- `agent:parallel-safe`

## Worktrees for local parallel agents

```bash
git fetch origin
git worktree add ../remotejarvis-ios -b feat/101-ios-task origin/main
git worktree add ../remotejarvis-host -b feat/102-host-task origin/main
```

Run a separate Codex/Claude session in each worktree.

## Integration strategy

- Keep `main` protected.
- Prefer squash merge for focused community PRs.
- Require CI before merge.
- Require maintainer review for security/protocol/core architecture.
- Avoid long-lived integration branches unless needed for a major migration.

## Discord onboarding

When sharing the repository in an AI-development Discord, point contributors to:
1. README
2. CONTRIBUTING
3. issues labelled `good first issue` / `help wanted`
4. project roadmap

Ask prospective contributors to claim an issue rather than posting large unsolicited rewrites.
