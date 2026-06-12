#!/usr/bin/env bash
# Local entry point: run the same CI lanes the hosted workflow runs, in order.
# There is no `fast`/pin lane in this repo — the jankurai pin is owned by
# jeryu-tool — so the gate is check + score + security (mirrors .github/workflows/ci.yml).
set -euo pipefail
bash ops/ci/check.sh
bash ops/ci/score.sh
bash ops/ci/security.sh
