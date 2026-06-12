set shell := ["bash", "-eu", "-o", "pipefail", "-c"]

# Full local gate (no `fast`/pin lane — the jankurai pin is owned by jeryu-tool).
default:
  ./ops/ci/check.sh
  ./ops/ci/score.sh
  ./ops/ci/security.sh

check:
  ./ops/ci/check.sh   # script syntax/compile + dossier selftest

score:
  ./ops/ci/score.sh   # jankurai audit repo-score

security:
  ./ops/ci/security.sh # gitleaks actionlint env-file

# Discovery surface.
scan *ARGS:
  python3 scripts/scan_family.py {{ARGS}}

dossier *ARGS:
  python3 scripts/dossier.py {{ARGS}}

propose CLUSTER *ARGS:
  python3 scripts/propose.py {{CLUSTER}} {{ARGS}}

summary *ARGS:
  python3 scripts/registry_summary.py {{ARGS}}

profile:
  printf '%s\n' "public-portal"
