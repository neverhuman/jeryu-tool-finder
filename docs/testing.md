# Testing

`jeryu-tool-finder` is a single Rust binary. Its tests are the `cargo test`
suite (unit + property tests under `src/`, end-to-end CLI tests in
`tests/finder.rs`), run inside the deterministic CI lanes alongside the audit.
Every lane is a script under `ops/ci/`; CI and local invoke the **same** scripts.

## Local gate

Run the full gate with one command:

```
just
```

or, with no `just` installed, the same lanes directly:

```
bash scripts/ci-local.sh   # check → score → security, in CI order
```

Run `scripts/ci-doctor.sh` first to confirm your environment carries every tool
the lanes depend on (`bash`, `cargo`, `git`, `python3` for the score lane,
`jankurai`; optional `just`,
`gitleaks`, `actionlint`).

## Lanes

There is **no `fast` lane** here — the jankurai pin is owned by `jeryu-tool`, so
this repo has no pin-drift lane (see `agent/proof-lanes.toml`).

- `just check` (`ops/ci/check.sh`) — every shell entrypoint under `ops/`
  parses, then `cargo fmt --check`, `cargo clippy --all-targets -- -D warnings`,
  and `cargo test`. This is the load-bearing test.
- `just score` (`ops/ci/score.sh`) — runs the pinned jankurai audit over this
  repo, writing `.jankurai/repo-score.json` (and a copy under `target/jankurai/`).
  The lane fails if the score drops below the floor in `agent/audit-policy.toml`,
  if any hard finding is present, or if any cap is applied.
- `just security` (`ops/ci/security.sh`) — gitleaks (secret scan), actionlint
  (workflow lint), and a committed-`.env` guard.

## The test suite

`tests/finder.rs` drives the built binary end to end, hermetically and offline:

- `scan → dossier → propose` over two temp fixture repos, including the propose
  idempotency contract and registry comment preservation;
- `dossier --selftest` against the bundled `fixtures/sample-clusters.json`,
  asserting the dossier shape and the anticipated-LOC-saved math;
- `summary` delegating to `jeryu-toolctl registry-summary` (a stub binary via
  `--toolctl`) from inside the `jeryu-tool` checkout, with passthrough
  arguments, and failing clearly when the binary is missing.

Property tests in `src/propose.rs` pin slug and TOML-rendering invariants. A
change that breaks any of these contracts fails `just check` immediately.

## CI parity & repair evidence

`.github/workflows/ci.yml` runs check → score → security — the identical
`ops/ci/*.sh` scripts the local gate and `ops/git-hooks/pre-push` call, so local
and hosted CI cannot diverge. When the score lane fails, the next agent reads the
structured evidence in `.jankurai/repo-score.json` (`caps_applied`, `findings`
with `agent_fix` and `rerun_command`, and `agent_fix_queue`) to find exactly
which path to repair and which lane to rerun.

The lanes surface failures as non-zero exits with a one-line cause on stderr
(missing tool, failed test, committed `.env`); the audit writes its full,
fingerprinted evidence to `.jankurai/repo-score.json`.

## Repair receipts

Every failure leaves a repair receipt that tells the next agent where to rerun
proof. A failed lane prints its cause on stderr and exits non-zero; the score
lane additionally writes a structured receipt to `.jankurai/repo-score.json`,
where each finding carries `path`, `agent_fix`, and `rerun_command` (and the
`agent_fix_queue` orders them). The repair loop is therefore: read the receipt,
fix the named `path`, and rerun the named lane (for this repo, `just check`,
`just score`, or `just security`) until the finding clears. See
`agent/JANKURAI_STANDARD.md` for the repair-receipt contract.
