# jeryu-tool-finder

[![CI](https://img.shields.io/badge/CI-check%20%7C%20score%20%7C%20security-blue)](.github/workflows/ci.yml)
[![jankurai score](https://img.shields.io/badge/jankurai-0%20caps-brightgreen)](agent/audit-policy.toml)

Agents start at **[AGENTS.md](AGENTS.md)** (the agent entrypoint); deeper docs
are indexed there and under [`docs/`](docs/).

The **tool-discovery** arm of the jeryu family. A single all-Rust CLI,
`jeryu-tool-finder`, that scans
**every** repo at once, find code that is duplicated across **more than one
repo**, and turn the strongest clusters into agent-readable dossiers — the leads
worth extracting into a shared tool.

`jeryu-tool` owns the *registry* of reusable tools; `jeryu-tool-finder` is what
*discovers candidates* for it. The loop:

```
jeryu-tool-finder scan     →  cross-repo clusters      (the codegraph engine, linked as a library)
jeryu-tool-finder dossier  →  one dossier per cluster  (files, examples, LOC saved)
  ↓ an agent/human reads a dossier and decides
jeryu-tool-finder propose  →  [[tool]] + build task in jeryu-tool   (status=proposed)
  ↓ jeryu-tool tracks build + adoption + LOC saved
forge golden box →  shows the payoff on /repos
```

## Subcommands

| Subcommand | What it does |
|---|---|
| `scan` | Runs the `jeryu-codegraph` engine over `repos.manifest.toml` (or every split family on the host with `--system`), folding all repos into one fingerprint index, and writes `dossiers/clusters.json`. |
| `dossier` | Enriches each cross-repo cluster into a dossier: per-repo file paths, normalized preview, suggested tool kind/name, and **anticipated LOC saved**. `dossier --selftest` proves the enrichment offline against `fixtures/sample-clusters.json`. |
| `propose <cluster_id>` | Promotes a chosen cluster into a `jeryu-tool` proposal — a `[[tool]]` entry (`status=proposed`) plus a `tasks/NNNN-*.toml` build task. Idempotent on `origin_cluster`; `--dry-run` previews. |
| `summary` | Prints the golden-box registry summary by delegating to `jeryu-toolctl registry-summary` inside the sibling `jeryu-tool` checkout (`--toolctl` / `JERYU_TOOLCTL` override the binary). |

## Engine wiring

The engine is `jeryu-intelligence/crates/jeryu-codegraph`, consumed **as a
library**: `Cargo.toml` pins a public git tag, and a `[patch]` section redirects
to the local split checkout for family development (jeryu-deploy's wiring). One
engine implementation serves this CLI, the live dashboard, and MCP, so cluster
ids and LOC numbers always agree.

## Quick start

```bash
bash scripts/ci-doctor.sh   # confirm required tooling (cargo, git, python3, jankurai)
just                        # the gate: check + score + security
# or without `just`:
bash scripts/ci-local.sh    # same lanes CI runs, in CI order
```

Wire the local gate to run before every push:

```bash
git config core.hooksPath ops/git-hooks
```

## Local commands

```bash
just scan       # scan the whole family for cross-repo clusters
just dossier    # render dossiers from the latest scan
just propose <cluster_id>   # file a proposal into jeryu-tool
just summary    # golden-box registry numbers (jeryu-toolctl registry-summary)
just            # the gate: check + score + security
```

## Docs

- [docs/architecture.md](docs/architecture.md) — components, boundaries, data flow
- [docs/tool-finder.md](docs/tool-finder.md) — dossier schema, LOC-saved definition
- [docs/testing.md](docs/testing.md) — CI lanes, the cargo test suite, CI parity
- [docs/release.md](docs/release.md) — version source, release gate, rollback
- [CHANGELOG.md](CHANGELOG.md) — release notes

Cross-repo cluster discovery and the `repo_count` shape live in
`jeryu-intelligence/crates/jeryu-codegraph` (`tool-build scan-family`). See
`docs/tool-finder.md` for the dossier schema, the LOC-saved definition, and the
known `candidate_repos` caveat.

## Governed auditor

CI invokes only the receipt-verified `/home/ubuntu/.jeryu/bin/jankurai` identity
rendered by `jeryu-tool`. The 1.6.11 auditor cutover is CI authority only; it
does not change this repository's product version, release tag, or artifacts.
