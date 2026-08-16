# Release

`jeryu-tool-finder` ships one Rust CLI. A release binds that executable, its
public help contract, exact source/tree, immutable Intelligence dependency,
score evidence, security evidence, and lockfile in a deterministic
artifact-support receipt.

## Version source

The release tag source is `VERSION` (for example,
`jeryu-tool-finder-v5.1.0-split.0`); its semver must equal the Cargo package
version and the compiled CLI's exact `--version` output. Release notes are recorded in
[`CHANGELOG.md`](../CHANGELOG.md). The sole family release authority is
`../jeryu-release-ops/repos.manifest.toml`; release transport follows the
protected local-forge lifecycle and immutable tag rules.

## Release gate

Before a release or split tag is promoted, confirm the full launch gate:

- run `bash scripts/ci-local.sh required` (or `just`): locked Rust check, score,
  security, CLI contract drift, and artifact support, in that order
- require the protected local-Jeryu `jeryu-tool-finder/required` check at the
  exact candidate head; the GitHub workflow is not release authority
- confirm `scripts/ci-doctor.sh` reports all required tooling present
- confirm the **security** lane is green: gitleaks (secret scan), actionlint
  (workflow lint), and the committed-`.env` guard all pass
- validate `target/artifact-support/jeryu-tool-finder.json`: `status=ready`,
  exact head/tree, the single-link mode-0555
  `target/artifact-support/jeryu-tool-finder` CLI checksum/size, VERSION/Cargo/
  toolchain/help digests, exact governed Cargo/rustc identity, fresh-private-
  target policy, and exact score/security evidence digests
- confirm the security evidence says Cargo audit `clean` and SPDX `generated`;
  missing tools or incomplete evidence leave artifact support red
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

The release gate is script-driven and deterministic. The protected local gate,
local runner, Just recipes, and pre-push hook compose the same repository-owned
lanes. The `propose` command is the one product operation that mutates a sibling
checkout; it writes into the `jeryu-tool` registry and must keep
`jeryu-tool`'s `ops/registry_summary.py --check` green.

## Integrity & provenance

The release coordinate is the immutable git commit at the split tag. The
artifact-support receipt binds the release executable to that commit/tree,
physical tracked-input digest, release identity, governed build tools, locked
inputs, CLI contract, score sidecar, and security sidecar. Those sidecars bind
the same source digest; score also binds the exact verified auditor and its
installation receipt where applicable. Re-running
`ops/ci/artifact-support.sh --validate-receipt` recomputes every digest and
refuses dirty, hidden-index, ambient-Git, symlinked, externally hard-linked,
stale, overridden, or incomplete custody.

## Rollback

Rollback restores the previous split tag: check out the prior `VERSION` commit,
re-run `bash scripts/ci-local.sh required` to confirm the older gate is still green, and
re-tag if a repair release is needed. Do **not** overwrite a published split tag —
publish a new repair tag instead. `dossiers/` is a regenerated zone, so no
release rollback ever needs to touch it; re-run `just scan && just dossier` to
rebuild it from the engine.

## Auditor-only CI cutovers

Changing the governed auditor is not a product release and leaves `VERSION`,
split tags, and product artifacts unchanged. Its release gate requires the
exact protected `jeryu-tool` source/tag/binary receipt, clean exact-head CI,
and independent approval before protected merge. The backup, monitoring,
rate-limit or abuse, checksum, SBOM, provenance, and rollback controls above
remain mandatory for any later product promotion.
