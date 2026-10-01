#!/usr/bin/env bash
# Canonical local PR gate for jeryu-tool-finder. split-host-ci prefers this
# script and posts the `jeryu-tool-finder/required` check-run from its exit
# status; .github/workflows/ci.yml runs the same lanes on the GitHub mirror so
# the two surfaces cannot diverge.
set -euo pipefail

# BEGIN GENERATED JANKURAI PIN — DO NOT EDIT
# The governed Jankurai identity is the binary installed on this host and its
# installation receipt: require_jankurai verifies both and exports JERYU_JANKURAI_*
# from the receipt. The one pin of record is jeryu-tool's tool-manifest.toml.
# END GENERATED JANKURAI PIN


repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$repo_root"

# Resolve and verify the absolute governed auditor before any lane runs.
source ops/ci/lib.sh
require_jankurai

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

# Verify only this PR worktree against the family manifest; the post-rollout
# control-plane check verifies the complete canonical family.
JERYU_TOOL_RENDER="${JERYU_TOOL_RENDER:-$repo_root/../jeryu-tool/ops/render-tool-manifest.sh}"
if [ -x "$JERYU_TOOL_RENDER" ]; then
  consumer_repo="$(awk -F'\"' '/^workspace =/ {print $2; exit}' agent/audit-policy.toml)"
  bash "$JERYU_TOOL_RENDER" --check --repo "$consumer_repo" \
    --repo-root "$consumer_repo=$repo_root"
fi

echo "[pr-ci] (jobs=$JOBS) standard lanes" >&2
bash ops/ci/check.sh
bash ops/ci/score.sh
bash tools/security-lane.sh
echo "[pr-ci] jeryu-tool-finder OK" >&2
