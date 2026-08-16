#!/usr/bin/env bash
# Structure check: the Rust finder builds clean (fmt/clippy/test) and the
# shell entrypoints are valid. The dossier fixture selftest rides cargo test.
set -euo pipefail
source ops/ci/lib.sh

# Shell entrypoints and their dispatch test must parse.
for script in scripts/*.sh tools/*.sh tests/*.sh ops/*.sh ops/ci/*.sh; do
  [[ -e "$script" ]] || continue
  bash -n "$script"
done

bash tests/ci_local_dispatch_test.sh

cargo fmt --check
cargo clippy --all-targets -- -D warnings
cargo test

printf 'check ok: %s\n' "$(pwd)"
