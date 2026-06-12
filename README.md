# jeryu-tool-finder

The **tool-discovery** arm of the jeryu family. Powerful scripts that scan
**every** repo at once, find code that is duplicated across **more than one
repo**, and turn the strongest clusters into agent-readable dossiers — the leads
worth extracting into a shared tool.

`jeryu-tool` owns the *registry* of reusable tools; `jeryu-tool-finder` is what
*discovers candidates* for it. The loop:

```
scan_family.py   →  cross-repo clusters         (drives the codegraph engine)
dossier.py       →  one dossier per cluster      (files, examples, LOC saved)
  ↓ an agent/human reads a dossier and decides
propose.py       →  [[tool]] + build task in jeryu-tool   (status=proposed)
  ↓ jeryu-tool tracks build + adoption + LOC saved
forge golden box →  shows the payoff on /repos
```

## Scripts

| Script | What it does |
|---|---|
| `scripts/scan_family.py` | Runs the `jeryu-codegraph tool-build scan-family` engine over `repos.manifest.toml` (all repos into one fingerprint index) and writes `dossiers/clusters.json`. |
| `scripts/dossier.py` | Enriches each cross-repo cluster into a dossier: per-repo file paths, normalized preview, suggested tool kind/name, and **anticipated LOC saved**. |
| `scripts/propose.py` | Promotes a chosen cluster into a `jeryu-tool` proposal — a `[[tool]]` entry (`status=proposed`) plus a `tasks/NNNN-*.toml` build task. Idempotent on `origin_cluster`. |
| `scripts/registry_summary.py` | Reads the golden-box summary from `jeryu-tool` (CLI/MCP convenience). |

## No version-pin burden

The engine is invoked as a **binary at runtime** (`JERYU_CODEGRAPH_BIN`, then
`PATH`, then a prebuilt `jeryu-intelligence/target/*/jeryu-codegraph`, then
`cargo run`). This repo takes **no Cargo dependency** on `jeryu-codegraph`, so the
family pin graph is unchanged — it is pure scripts + docs.

## Local commands

```bash
just scan       # scan the whole family for cross-repo clusters
just dossier    # render dossiers from the latest scan
just summary    # golden-box registry numbers (from jeryu-tool)
just            # the gate: check + score + security
```

Cross-repo cluster discovery and the `repo_count` shape live in
`jeryu-intelligence/crates/jeryu-codegraph` (`tool-build scan-family`). See
`docs/tool-finder.md` for the dossier schema, the LOC-saved definition, and the
known `candidate_repos` caveat.
