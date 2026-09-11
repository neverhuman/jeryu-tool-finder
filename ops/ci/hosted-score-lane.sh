#!/usr/bin/env bash
set -euo pipefail
jankurai security run . --strict --profile ci --out target/jankurai/security/evidence.json
bash ops/ci/score.sh
jankurai audit . --mode ratchet --baseline target/jankurai/accepted-baseline.json --json target/jankurai/repo-score.json --md target/jankurai/repo-score.md
