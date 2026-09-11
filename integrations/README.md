# Integration boundary

The archive contains pinned third-party snapshots and local runtime copies for fullstack-agent, Backtalk, ai-visualizer, barehands and ai-memory-vault. There is no first-party Codex or Claude adapter module to move here yet.

`Configuration/upstream.lock.json` preserves full commit IDs, source directory names and the archive checksums observed during the audit. Runtime copies and downloads remain in ignored root `upstream/` and `runtime/`; the local staging/launch scripts remain under root `scripts/` to preserve path behavior.

The source files shared between each upstream snapshot and its runtime copy are byte-identical. Runtime-only configuration, installed dependencies and initialized memory are local data, not new integration source. Do not replace pinned snapshots with latest-branch downloads during migration.

`backtalk/uv.lock` is the one reviewed runtime-derived dependency artifact retained publicly. Its package registry is public PyPI and its virtual-project reference is relative. It is absent from the upstream snapshot. Copy it unchanged into a freshly staged local Backtalk directory before sync, and refuse to overwrite a different existing lock. The lockfile is not a first-party agent adapter.

The four code repositories include AGPLv3 license text; ai-memory-vault includes CC BY-SA 4.0 text. Keep provenance and notices, and resolve redistribution scope before vendoring or relicensing any upstream material.
