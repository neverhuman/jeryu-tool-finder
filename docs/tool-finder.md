# jeryu-tool-finder

How the family finds code worth turning into a shared tool, and how a candidate
becomes a tracked tool in `jeryu-tool`.

## The engine vs. this repo

The heavy cross-repo clustering lives in
`jeryu-intelligence/crates/jeryu-codegraph` (`tool-build scan-family`): it walks
every repo in `repos.manifest.toml`, normalizes identifier/literal tokens,
fingerprints fixed-size line windows with BLAKE3, and folds **all repos into one
index** so a window seen in more than one repo becomes a single cluster with
`repo_count >= 2`.

This repo is the **operator surface**: scripts that drive that engine across the
family, render dossiers, and file proposals. It is pure Python + docs and takes
no Cargo dependency — the engine is a runtime binary.

## Pipeline

1. **`scan_family.py`** → `dossiers/clusters.json`. Resolves the engine
   (`JERYU_CODEGRAPH_BIN` → `PATH` → `jeryu-intelligence/target/*` → `cargo run`)
   and runs `tool-build scan-family --min-repos 2`.
2. **`dossier.py`** → `dossiers/<cluster>.md` + `dossiers/index.json`. One dossier
   per cluster with: per-repo file paths and line ranges, the normalized window
   preview, a suggested tool `kind`/`name`, and the **anticipated LOC saved**.
3. **decision** — an LLM/agent (or a human) reads a dossier and decides whether
   the cluster is worth extracting into a shared tool.
4. **`propose.py <cluster_id>`** → appends a `[[tool]]` (`status=proposed`) and a
   `tasks/NNNN-*.toml` build task to the sibling `jeryu-tool` repo, with a
   per-repo rollout stub. Idempotent on `origin_cluster`.

## Dossier fields

`cluster_id`, `language`, `repo_count`, `occurrence_count`, `file_count`,
`score`, `anticipated_loc_saved`, `suggested_kind`, `suggested_name`,
`candidate_repos`, `insight`, `normalized_preview`, and `examples_by_repo`
(repo → up to six `path:start-end` locations).

## LOC-saved definition

Anticipated LOC saved for a cluster is a **conservative lower bound**:
`total_lines − window_span`, i.e. the lines removed by collapsing all but one
copy of the repeated window (`(occurrences − 1) × window_lines`). It matches the
`loc_saved_estimate` written into `jeryu-tool`'s registry; realized `loc_saved`
grows as repos actually migrate.

## Known caveat: `candidate_repos`

The engine caps stored `occurrences` per cluster for compact responses, so for a
cluster that spans many repos `candidate_repos` (derived from the visible
occurrences) can **undercount** while `repo_count` stays accurate. `propose.py`
therefore writes a *starting* candidate list; the reviewing agent is expected to
widen `target_repos`/`candidate_repos` to the full `repo_count` before the
rollout. Treat the proposal as a draft, not the final migration set.

## Why split out (not folded into jeryu-intelligence)

Keeping discovery here, as scripts, means the family gets a dedicated, evolvable
finder surface (more search modalities, richer dossiers, scheduled scans) without
adding a Cargo crate or a new version-pin edge. The reusable analysis primitive
stays in jeryu-intelligence where the rest of codegraph lives; only the
orchestration is split out.
