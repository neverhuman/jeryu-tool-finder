#!/usr/bin/env bash
# Structure check: the finder scripts compile, the shell entrypoints are valid,
# and the dossier logic passes its hermetic selftest (no engine/cargo needed).
set -euo pipefail
source ops/ci/lib.sh

# Python scripts must byte-compile.
python3 -m py_compile scripts/*.py

# Shell entrypoints must parse.
for script in ops/*.sh ops/ci/*.sh; do
  [[ -e "$script" ]] || continue
  bash -n "$script"
done

# Dossier enrichment must survive against the bundled fixture (offline).
python3 scripts/dossier.py --selftest

printf 'check ok: %s\n' "$(pwd)"
