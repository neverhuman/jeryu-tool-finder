set shell := ["bash", "-eu", "-o", "pipefail", "-c"]

# Full local gate (no `fast`/pin lane — the jankurai pin is owned by jeryu-tool).
default:
  ./ops/ci/check.sh
  ./ops/ci/score.sh
  ./ops/ci/security.sh

check:
  ./ops/ci/check.sh   # cargo fmt/clippy/test + shell syntax

score:
  ./ops/ci/score.sh   # jankurai audit repo-score

security:
  ./ops/ci/security.sh # gitleaks actionlint env-file

# Dependency review (advisories, licenses, sources). Needs network; CI runs it.
security-deps:
  JERYU_SECURITY_NETWORK=1 cargo deny check

build:
  cargo build --release

# Discovery surface (all-Rust; the engine is linked as a library).
scan *ARGS:
  cargo run --release -- scan {{ARGS}}

dossier *ARGS:
  cargo run --release -- dossier {{ARGS}}

propose CLUSTER *ARGS:
  cargo run --release -- propose {{CLUSTER}} {{ARGS}}

summary *ARGS:
  cargo run --release -- summary {{ARGS}}

profile:
  printf '%s\n' "public-portal"
