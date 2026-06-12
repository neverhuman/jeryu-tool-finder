# Jeryu Split Repo Standard

Split repo: `jeryu-tool-finder`
Required check: `jeryu-tool-finder/required`
Profile: `public-portal` (scripts/docs discovery arm — no product code)

Required local commands are `just check`, `just score`, and `just security`.
`just` (no recipe) runs the full local gate in one command, and the GitHub
workflow runs the same lanes so CI and local stay at parity.

There is **no `fast` lane** here: the jankurai pin is the single source of truth
in `jeryu-tool`'s `tool-manifest.toml`, not in this repo. This repo carries no
pinned consumers to drift.

The discovery surface (`just scan` / `just dossier` / `just propose`) drives the
`jeryu-codegraph` engine as a runtime binary; this repo takes no Cargo dependency.

Generated zones are not hand-edited: `.jankurai/**` is produced by `just score`,
and `dossiers/**` is produced by `just scan` + `just dossier`.
