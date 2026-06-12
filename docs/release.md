# Release

`jeryu-tool-finder` ships **no binary of its own** — it is pure Python scripts
plus docs. A "release" here is a split tag that pins the discovery scripts and
the dossier/proposal contract the rest of the family consumes.

## Version source

The version source is the `VERSION` file (the split tag, e.g.
`jeryu-tool-finder-v5.1.0-split.0`). Release notes are recorded in
[`CHANGELOG.md`](../CHANGELOG.md). The signed release artifacts for the whole
family are published by `neverhuman/jeryu-deploy`; this repo contributes only its
source at the pinned tag.

## Release gate

Before a release or split tag is promoted, confirm the full launch gate:

- run the full gate locally: `bash scripts/ci-local.sh` (or `just`), which runs
  `ops/ci/check.sh` (script compile + `dossier.py --selftest`), `ops/ci/score.sh`
  (the pinned jankurai audit), and `ops/ci/security.sh`
- confirm the same lanes are green in hosted CI (`.github/workflows/ci.yml` runs
  check → score → security, at parity with the local gate)
- confirm `scripts/ci-doctor.sh` reports all required tooling present
- confirm the **security** lane is green: gitleaks (secret scan), actionlint
  (workflow lint), and the committed-`.env` guard all pass
- confirm **checksum, provenance, and SBOM** policy: there is no compiled
  artifact here, so the provenance is the immutable tagged source plus the
  fingerprinted audit evidence in `target/jankurai/repo-score.json`
- confirm **backups / reproducible inputs exist for rollback**: the prior split
  tag is the backup; `dossiers/` is regenerable from the engine, never a backup
  dependency
- confirm **monitoring** of the rollout: the score lane is the live monitor — it
  fails the gate the moment the repo drops below floor or grows a cap
- confirm **rate-limit / abuse / budget controls**: this repo exposes no public
  runtime surface and runs no paid or unbounded operation, so these are N/A by
  design; the only external work is the codegraph engine invocation, bounded by
  `--min-repos` and the local repo set
- update `CHANGELOG.md` and bump `VERSION` to the new split tag

## Release automation & command policy

The release gate is script-driven and deterministic: the lanes in `ops/ci/` are
the automation. CI (`.github/workflows/ci.yml`) and the local runner
(`scripts/ci-local.sh`) and the pre-push hook (`ops/git-hooks/pre-push`) all call
the **same** `ops/ci/*.sh` scripts, so a release can never pass CI while failing
locally. No release step mutates state outside the working tree except
`propose.py`, which writes into the sibling `jeryu-tool` registry and must keep
`jeryu-tool`'s `ops/registry_summary.py --check` green.

## Integrity & provenance

The release coordinate is the immutable git commit at the split tag. There is no
compiled artifact to checksum or SBOM here; provenance is the tagged source plus
the audit evidence the score lane writes to `target/jankurai/repo-score.json`
(fingerprinted: `report_fingerprint`, `input_fingerprint`, `policy_fingerprint`).
The pinned auditor itself is governed by `jeryu-tool`'s `tool-manifest.toml`; this
repo verifies it via `jankurai --version` in `ops/ci/lib.sh` before scoring.

## Rollback

Rollback restores the previous split tag: check out the prior `VERSION` commit,
re-run `bash scripts/ci-local.sh` to confirm the older gate is still green, and
re-tag if a repair release is needed. Do **not** overwrite a published split tag —
publish a new repair tag instead. `dossiers/` is a regenerated zone, so no
release rollback ever needs to touch it; re-run `just scan && just dossier` to
rebuild it from the engine.
