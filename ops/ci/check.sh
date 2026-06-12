#!/usr/bin/env bash
# Structure check: the Rust finder builds clean (fmt/clippy/test) and the
# shell entrypoints are valid. The dossier fixture selftest rides cargo test.
set -euo pipefail
source ops/ci/lib.sh

# Shell entrypoints must parse.
for script in ops/*.sh ops/ci/*.sh; do
  [[ -e "$script" ]] || continue
  bash -n "$script"
done

cargo fmt --check
cargo clippy --all-targets -- -D warnings
cargo test

printf 'check ok: %s\n' "$(pwd)"
