# Testing

`jeryu-tool-finder` has no compiled product to unit-test, so its "tests" are the
deterministic CI lanes over the scripts, the dossier selftest, and the audit.
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
the lanes depend on (`bash`, `python3`, `git`, `jankurai`; optional `just`,
`gitleaks`, `actionlint`).

## Lanes

There is **no `fast` lane** here — the jankurai pin is owned by `jeryu-tool`, so
this repo has no pin-drift lane (see `agent/proof-lanes.toml`).

- `just check` (`ops/ci/check.sh`) — every `scripts/*.py` byte-compiles, every
  shell entrypoint under `ops/` parses, and `scripts/dossier.py --selftest`
  passes against `fixtures/sample-clusters.json`. This is the load-bearing test.
- `just score` (`ops/ci/score.sh`) — runs the pinned jankurai audit over this
  repo, writing `.jankurai/repo-score.json` (and a copy under `target/jankurai/`).
  The lane fails if the score drops below the floor in `agent/audit-policy.toml`,
  if any hard finding is present, or if any cap is applied.
- `just security` (`ops/ci/security.sh`) — gitleaks (secret scan), actionlint
  (workflow lint), and a committed-`.env` guard.

## The dossier selftest

The dossier enrichment is the one piece of real logic in this repo, so it carries
a hermetic, offline selftest. `scripts/dossier.py --selftest` loads
`fixtures/sample-clusters.json`, runs the full enrichment, and asserts the dossier
shape and the anticipated-LOC-saved math without touching the codegraph engine or
the network. `ops/ci/check.sh` runs it on every gate, so a change to the dossier
schema that breaks the contract fails CI immediately.

## CI parity & repair evidence

`.github/workflows/ci.yml` runs check → score → security — the identical
`ops/ci/*.sh` scripts the local gate and `ops/git-hooks/pre-push` call, so local
and hosted CI cannot diverge. When the score lane fails, the next agent reads the
structured evidence in `.jankurai/repo-score.json` (`caps_applied`, `findings`
with `agent_fix` and `rerun_command`, and `agent_fix_queue`) to find exactly
which path to repair and which lane to rerun.

The scripts surface failures as non-zero exits with a one-line cause on stderr
(missing tool, failed selftest, committed `.env`); the audit writes its full,
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
