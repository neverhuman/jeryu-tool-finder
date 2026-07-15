#!/usr/bin/env bash
# Doctor: confirm the local environment carries every tool the ops/ci scripts
# depend on, so a developer can see at a glance whether local matches CI.
set -euo pipefail

# BEGIN GENERATED JANKURAI PIN — DO NOT EDIT
export JERYU_GOVERNED_JANKURAI_BIN="${JERYU_JANKURAI_BIN:-/home/ubuntu/.jeryu/bin/jankurai}"
export JERYU_JANKURAI_VERSION="jankurai 1.6.11"
export JERYU_JANKURAI_SHA256="fdb42e5fa7d9851c0729e59bf1e582c895aa9cfc03a7175b420c6025d2fd014e"
export JERYU_JANKURAI_SOURCE_REV="dface7397fe24d46b0b1885ddd5782c34edbff49"
export JERYU_JANKURAI_SOURCE_TAG="v1.6.11-deadlang-precision-split.1"
export JERYU_JANKURAI_SOURCE_TREE="34a8a1fb59bc4ebfadf12c45d95f169d06acc781"
export JERYU_JANKURAI_SOURCE_ARCHIVE_SHA256="2fbca5d04083e3c8d32f383d5b6b4520b8911690b26968c6fbcb210e1202b938"
export JERYU_JANKURAI_CARGO_LOCK_SHA256="b9acb981c326226a687d0b6703e4f7ee303148e9e1a6dda1aa03d77988820f6a"
export JERYU_JANKURAI_RUST_TOOLCHAIN="1.95.0"
export JERYU_JANKURAI_TARGET_TRIPLE="x86_64-unknown-linux-gnu"
# END GENERATED JANKURAI PIN

source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/ops/ci/lib.sh"
require_jankurai

# Required: the lanes (check/score/security) cannot run without these.
required=(bash python3 git cargo jankurai)
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
