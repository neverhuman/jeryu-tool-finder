#!/usr/bin/env bash
# Canonical local PR gate for jeryu-tool-finder. split-host-ci prefers this
# script and posts the `jeryu-tool-finder/required` check-run from its exit
# status; .github/workflows/ci.yml runs the same lanes on the GitHub mirror so
# the two surfaces cannot diverge.
set -euo pipefail
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$repo_root"

# jeryu governs the worker count from live load; never default high.
if [ -n "${JERYU_CI_JOBS:-}" ]; then
  JOBS="${JERYU_CI_JOBS}"
elif command -v jeryu-ci-governor >/dev/null 2>&1; then
  JOBS="$(jeryu-ci-governor 2>/dev/null || echo 8)"
else
  JOBS=8
fi
export JERYU_CI_JOBS="$JOBS"
export CARGO_BUILD_JOBS="${CARGO_BUILD_JOBS:-$JOBS}"
export PATH="${CARGO_HOME:-$HOME/.cargo}/bin:$PATH"

echo "[pr-ci] (jobs=$JOBS) standard lanes" >&2
bash ops/ci/check.sh
bash ops/ci/score.sh
bash ops/ci/security.sh
echo "[pr-ci] jeryu-tool-finder OK" >&2
