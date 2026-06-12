#!/usr/bin/env bash
set -euo pipefail

# Resolve the family-pinned auditor the same way the authoritative Layer-2
# scoring funnel does (jeryu-deploy ops/ci/common.sh): JERYU_JANKURAI_BIN,
# defaulting to the jeryu-managed global install. PATH is the last resort —
# stray jankurai builds carry drifted heuristics and inconsistent caps.
JANKURAI_BIN="${JERYU_JANKURAI_BIN:-$HOME/.jeryu/bin/jankurai}"
if [[ ! -x "$JANKURAI_BIN" ]]; then
  JANKURAI_BIN="jankurai"
fi

require_tool() {
  local name="$1"
  command -v "$name" >/dev/null 2>&1 || {
    printf 'missing required tool: %s\n' "$name" >&2
    exit 1
  }
}

require_jankurai() {
  local expected="jankurai 1.6.10"
  local actual
  actual="$("$JANKURAI_BIN" --version 2>/dev/null || true)"
  if [[ "$actual" != "$expected" ]]; then
    printf 'expected %s, got %s\n' "$expected" "${actual:-missing jankurai}" >&2
    exit 1
  fi
}
