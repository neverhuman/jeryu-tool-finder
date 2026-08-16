#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
validator="$repo_root/ops/ci/artifact-support.sh"
receipt="$repo_root/target/artifact-support/jeryu-tool-finder.json"
score="$repo_root/target/jankurai/evidence.json"
security="$repo_root/target/security/evidence.json"
test_dir="$repo_root/target/artifact-support"
stderr_log="$test_dir/.hostile.stderr"
receipt_saved=''
security_saved=''

cleanup() {
  rm -f -- "$test_dir/.receipt-hardlink" \
    "$repo_root/target/jankurai/.evidence-hardlink" "$stderr_log"
  if [[ -L "$receipt" ]]; then
    rm -- "$receipt"
  fi
  if [[ -n "$receipt_saved" && -f "$receipt_saved" ]]; then
    rm -f -- "$receipt"
    mv -- "$receipt_saved" "$receipt"
  fi
  if [[ -n "$security_saved" && -f "$security_saved" ]]; then
    rm -f -- "$security"
    mv -- "$security_saved" "$security"
  fi
}
trap cleanup EXIT

fail() {
  printf 'artifact-support hostile test failed: %s\n' "$1" >&2
  sed -n '1,12p' "$stderr_log" >&2
  exit 1
}

expect_invalid() {
  if bash "$validator" --validate-receipt > /dev/null 2> "$stderr_log"; then
    fail "$1"
  fi
}

bash "$validator" --validate-receipt >/dev/null

ln -- "$receipt" "$test_dir/.receipt-hardlink"
expect_invalid 'multiply linked receipt passed validation'
rm -- "$test_dir/.receipt-hardlink"
bash "$validator" --validate-receipt >/dev/null

receipt_saved="$test_dir/.receipt-saved"
mv -- "$receipt" "$receipt_saved"
ln -s -- "$(basename "$receipt_saved")" "$receipt"
expect_invalid 'symlinked receipt passed validation'
rm -- "$receipt"
mv -- "$receipt_saved" "$receipt"
receipt_saved=''
bash "$validator" --validate-receipt >/dev/null

receipt_saved="$test_dir/.receipt-saved"
mv -- "$receipt" "$receipt_saved"
jq '.status = "bootstrap"' "$receipt_saved" > "$receipt"
chmod 0600 "$receipt"
expect_invalid 'non-ready receipt passed validation'
rm -- "$receipt"
mv -- "$receipt_saved" "$receipt"
receipt_saved=''
bash "$validator" --validate-receipt >/dev/null

ln -- "$score" "$repo_root/target/jankurai/.evidence-hardlink"
expect_invalid 'multiply linked score evidence passed validation'
rm -- "$repo_root/target/jankurai/.evidence-hardlink"
bash "$validator" --validate-receipt >/dev/null

security_saved="$repo_root/target/security/.evidence-saved"
mv -- "$security" "$security_saved"
expect_invalid 'missing security evidence passed validation'
mv -- "$security_saved" "$security"
security_saved=''
bash "$validator" --validate-receipt >/dev/null

printf 'artifact-support hostile tests ok\n'
