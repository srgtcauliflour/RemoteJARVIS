# Upstream provenance and migration notice

This import preserves authored source from the RemoteJARVIS snapshot audited on 2026-09-11.

## First-party license

The maintainer (A-Ron / srgtcauliflour) has chosen the **GNU Affero General Public License v3.0 or later (AGPL-3.0-or-later)** for the first-party RemoteJARVIS source in this repository, recorded 2026-09-11. The full text is in `LICENSE` at the repository root. This choice keeps the project's license consistent with its own runtime dependencies (fullstack-agent, Backtalk, ai-visualizer and barehands, all AGPLv3 per their recorded snapshots), which are not vendored by this import but are expected integration points.

This choice does not relicense third-party or adapted material described below; that material keeps its own license and attribution.

`scripts/Initialize-Memory.ps1` identifies its initial vault structure, daily-note pattern, boot sequence and maintenance rules as adapted from ai-memory-vault by Jared Rhodenizer, pinned at commit `659bba9c8b351c937dd393b3042801d1ff1b502c`:

- Source: https://github.com/jaredrhod/ai-memory-vault/tree/659bba9c8b351c937dd393b3042801d1ff1b502c
- Included original license text: `LICENSES/ai-memory-vault-CC-BY-SA-4.0.txt`
- RemoteJARVIS adaptations are contained in the existing initializer; migration relocates/imports the file without editing its contents.
- The CC BY-SA 4.0 license governs that adapted content specifically; it is compatible with inclusion in an AGPL-3.0-or-later project as an attributed, separately-licensed component, since CC BY-SA is not applied here to software distributed under AGPL terms — it continues to cover the adapted documentation/structure text itself, per the upstream project's own license.

The recorded dependency manifest also identifies fullstack-agent, Backtalk, ai-visualizer and barehands. Their snapshots include GNU Affero General Public License version 3 text. Their source and runtime copies are not vendored by this import. ai-visualizer also carries a font license in `assets/VT323-OFL.txt` in its pinned snapshot.

This notice records observed provenance and the maintainer's license decision. It is not legal advice, and does not by itself resolve every question a future contribution or redistribution might raise about the adapted material — maintainers should still re-review before accepting significant external contributions.
