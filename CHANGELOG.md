# Changelog

Release notes for `jeryu-tool-finder`. Version source is `VERSION`; the split
tag it carries is the release coordinate for the family. This repo ships no
binary — its "releases" are the discovery scripts and the dossier/proposal
contract they emit into `jeryu-tool`.

## Unreleased

### Added
- New family repo `jeryu-tool-finder`: the tool-discovery arm of the split.
- `scripts/scan_family.py` — drives `jeryu-codegraph tool-build scan-family`
  over `repos.manifest.toml` and writes `dossiers/clusters.json`.
- `scripts/dossier.py` — enriches each cross-repo cluster into an agent-readable
  dossier (per-repo file paths, normalized preview, anticipated LOC saved). Ships
  a hermetic `--selftest` over `fixtures/sample-clusters.json`.
- `scripts/propose.py` — promotes a chosen cluster into a `jeryu-tool` proposal
  (`[[tool]]` + `tasks/NNNN-*.toml`). Idempotent on `origin_cluster`.
- `scripts/registry_summary.py` — reads the golden-box registry summary from
  `jeryu-tool`.
- CI gate (`ops/ci/check.sh`, `ops/ci/score.sh`, `ops/ci/security.sh`) plus the
  local-parity surface (`scripts/ci-local.sh`, `scripts/ci-doctor.sh`,
  `ops/git-hooks/pre-push`).
- Agent-readable docs: `docs/architecture.md`, `docs/testing.md`,
  `docs/release.md`, `docs/tool-finder.md`, routed from `AGENTS.md`.
