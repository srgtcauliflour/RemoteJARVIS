# Local configuration examples

These examples document the settings observed in the migration archive. They are not loaded automatically and contain placeholder paths. The existing `scripts/Stage-Host.ps1` generates configuration under ignored `runtime/` using the checkout's real paths and preserves existing files.

For a fresh local installation, run staging after restoring the pinned upstream snapshots. Inspect the resulting configuration before launching a component. The audited runtime additionally sets `stt_device` to `cpu`; the staging script does not currently generate that field. To reproduce the audited speech configuration, explicitly add that setting to the local Backtalk configuration. Do not change the script's defaults during source migration.

Preserve an existing installation's configuration and personal vault privately before relocating it. Absolute paths in Backtalk, visualizer, `runtime/agent/CLAUDE.md`, `runtime/config/MEMORY.md.for-claude`, and the vault index need local updates if the checkout location changes. Never replace an existing vault with a freshly generated template.

No `.env` loader, API-key variable, RP domain, signing team, or credential is introduced by this migration.
