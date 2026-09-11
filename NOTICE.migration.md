# Upstream provenance and migration notice

This import preserves authored source from the RemoteJARVIS snapshot audited on 2026-09-11. It does not choose a license for the first-party project. The maintainer must settle that choice and the treatment of adapted material before public source publication.

`scripts/Initialize-Memory.ps1` identifies its initial vault structure, daily-note pattern, boot sequence and maintenance rules as adapted from ai-memory-vault by Jared Rhodenizer, pinned at commit `659bba9c8b351c937dd393b3042801d1ff1b502c`:

- Source: https://github.com/jaredrhod/ai-memory-vault/tree/659bba9c8b351c937dd393b3042801d1ff1b502c
- Included original license text: `LICENSES/ai-memory-vault-CC-BY-SA-4.0.txt`
- RemoteJARVIS adaptations are contained in the existing initializer; migration relocates/imports the file without editing its contents.

The recorded dependency manifest also identifies fullstack-agent, Backtalk, ai-visualizer and barehands. Their snapshots include GNU Affero General Public License version 3 text. Their source and runtime copies are not vendored by this import. ai-visualizer also carries a font license in `assets/VT323-OFL.txt` in its pinned snapshot.

This notice records observed provenance; it is not a completed licensing determination for the combined project or a claim that an added MIT/Apache license would cover third-party material.
