#!/usr/bin/env bash
# Doctor: confirm the local environment carries every tool the ops/ci scripts
# depend on, so a developer can see at a glance whether local matches CI.
set -euo pipefail

# Required: the lanes (check/score/security) cannot run without these.
required=(bash python3 git jankurai)
# Optional: security.sh runs these when present, and `just` is the lane wrapper.
optional=(just gitleaks actionlint)

missing=0
echo "ci-doctor: required tools"
for tool in "${required[@]}"; do
  if command -v "$tool" >/dev/null 2>&1; then
    printf '  ok   %s (%s)\n' "$tool" "$(command -v "$tool")"
  else
    printf '  MISS %s\n' "$tool"
    missing=1
  fi
done

echo "ci-doctor: optional tools"
for tool in "${optional[@]}"; do
  if command -v "$tool" >/dev/null 2>&1; then
    printf '  ok   %s (%s)\n' "$tool" "$(command -v "$tool")"
  else
    printf '  --   %s (optional; lane degrades gracefully)\n' "$tool"
  fi
done

# The pinned auditor version must match what ops/ci/lib.sh requires.
if command -v jankurai >/dev/null 2>&1; then
  printf 'ci-doctor: %s\n' "$(jankurai --version 2>/dev/null || echo 'jankurai --version failed')"
fi

if [[ "$missing" -ne 0 ]]; then
  printf 'ci-doctor: required tooling missing\n' >&2
  exit 1
fi
printf 'ci-doctor ok\n'
