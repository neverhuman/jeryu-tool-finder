# ops/ Agent Instructions

This cell owns the **CI gate** and the **local-parity surface** for
`jeryu-tool-finder`.

## Owns
- `ops/ci/*.sh` — the deterministic lanes: `check.sh` (script compile + dossier
  selftest), `score.sh` (pinned jankurai audit), `security.sh` (gitleaks /
  actionlint / committed-`.env`), and the shared `ops/ci/lib.sh` guards.
- `ops/git-hooks/pre-push` — the mandatory local gate (wire once with
  `git config core.hooksPath ops/git-hooks`).
- `.github/workflows/ci.yml` — must run the **same** lanes, in the same order, as
  the local gate (check → score → security). Keep CI and local at parity.

## Forbidden
- No `fast`/pin-drift lane here — the jankurai pin is owned by `jeryu-tool`, not
  this repo. Do not add a local pin source.
- Do not weaken a lane to make the gate pass (no skipping the selftest, no
  lowering the floor to hide a cap). Caps must reach zero on their own.
- Do not add a Cargo/build dependency; this repo is pure Python scripts + docs.

## Proof lane
- Edits under `ops/` are re-verified by `just check` (and the audit via
  `just score`). Run `bash scripts/ci-local.sh` before pushing; `scripts/ci-doctor.sh`
  confirms the required tooling is present. See `../docs/testing.md`.
