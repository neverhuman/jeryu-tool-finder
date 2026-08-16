#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"
cd "$repo_root"
source "$repo_root/ops/ci/lib.sh"
require_jankurai

die() {
  printf 'score check failed: %s\n' "$*" >&2
  exit 1
}

prepare_dir() {
  local relative="$1"
  local path="$repo_root/$relative"
  [[ ! -L "$path" ]] || die "$relative must not be a symlink"
  mkdir -p -- "$path"
  [[ -d "$path" ]] || die "$relative is not a directory"
  [[ "$(realpath -e -- "$path")" == "$path" ]] ||
    die "$relative escapes the repository"
}

clear_output() {
  local relative="$1"
  local path="$repo_root/$relative"
  if [[ -e "$path" || -L "$path" ]]; then
    [[ -f "$path" && ! -L "$path" ]] || die "$relative is not a regular file"
    [[ "$(stat -c '%h' "$path")" -eq 1 ]] || die "$relative is multiply linked"
    rm -- "$path"
  fi
}

head_sha="$(git rev-parse --verify HEAD)"
tree_sha="$(git rev-parse --verify 'HEAD^{tree}')"
[[ -z "$(git status --porcelain=v1 --untracked-files=all)" ]] ||
  die 'source checkout must be clean before scoring'

required=(
  agent/owner-map.json
  agent/test-map.json
  agent/generated-zones.toml
  agent/proof-lanes.toml
  agent/audit-policy.toml
  agent/boundaries.toml
  agent/JANKURAI_STANDARD.md
)
for path in "${required[@]}"; do
  [[ -s "$path" ]] || { printf 'missing split metadata: %s\n' "$path" >&2; exit 1; }
done
prepare_dir .jankurai
prepare_dir target
prepare_dir target/jankurai
clear_output .jankurai/repo-score.json
clear_output .jankurai/repo-score.md
clear_output target/jankurai/evidence.json
"$JANKURAI_BIN" audit . --full --mode advisory --policy agent/audit-policy.toml --json .jankurai/repo-score.json --md .jankurai/repo-score.md
python3 - <<'PY'
import json
import sys
from pathlib import Path
report = json.loads(Path(".jankurai/repo-score.json").read_text())
score = int(report.get("score") or 0)
floor = 85
try:
    import tomllib
    floor = int(tomllib.loads(Path("agent/audit-policy.toml").read_text()).get("minimum_score", 85))
except Exception:
    pass
caps = report.get("caps_applied") or report.get("caps") or []
decision = report.get("decision") if isinstance(report.get("decision"), dict) else {}
hard = decision.get("hard_findings", report.get("hard_findings", 0))
hard_count = len(hard) if isinstance(hard, list) else int(hard or 0)
errors = []
if score < floor:
    errors.append(f"score {score} is below {floor}")
if caps:
    errors.append(f"caps present: {', '.join(str(item) for item in caps)}")
if hard_count:
    errors.append(f"hard findings present: {hard_count}")
if errors:
    print("score check failed: " + "; ".join(errors), file=sys.stderr)
    sys.exit(1)
PY
clear_output target/jankurai/repo-score.json
clear_output target/jankurai/repo-score.md
cp -- .jankurai/repo-score.json target/jankurai/repo-score.json
cp -- .jankurai/repo-score.md target/jankurai/repo-score.md
chmod 0600 target/jankurai/repo-score.json target/jankurai/repo-score.md

[[ "$(git rev-parse --verify HEAD)" == "$head_sha" ]] || die 'HEAD moved while scoring'
[[ "$(git rev-parse --verify 'HEAD^{tree}')" == "$tree_sha" ]] ||
  die 'tree moved while scoring'
[[ -z "$(git status --porcelain=v1 --untracked-files=all)" ]] ||
  die 'source checkout changed while scoring'

report=target/jankurai/repo-score.json
[[ -f "$report" && ! -L "$report" && "$(stat -c '%h' "$report")" -eq 1 ]] ||
  die 'score report lacks regular single-link custody'
report_sha="$(sha256sum "$report" | awk '{print $1}')"
policy_sha="$(sha256sum agent/audit-policy.toml | awk '{print $1}')"
minimum_score="$(awk -F= '/^[[:space:]]*minimum_score[[:space:]]*=/ {
  gsub(/[[:space:]]/, "", $2); print $2; exit
}' agent/audit-policy.toml)"
[[ "$minimum_score" =~ ^[0-9]+$ ]] || die 'minimum_score is not an integer'
score="$(jq -er '.score | numbers' "$report")"
raw_score="$(jq -er '.raw_score | numbers' "$report")"
report_fingerprint="$(jq -er '.report_fingerprint | select(test("^sha256:[0-9a-f]{64}$"))' "$report")"
input_fingerprint="$(jq -er '.input_fingerprint | select(test("^sha256:[0-9a-f]{64}$"))' "$report")"
policy_fingerprint="$(jq -er '.policy_fingerprint | select(test("^sha256:[0-9a-f]{64}$"))' "$report")"

evidence_tmp="$(mktemp "$repo_root/target/jankurai/.evidence.XXXXXX")"
trap 'rm -f -- "${evidence_tmp:-}"' EXIT
jq -nS \
  --arg schema_version 'jeryu.split.score/v1' \
  --arg repo 'jeryu-tool-finder' \
  --arg status 'pass' \
  --arg head "$head_sha" \
  --arg tree "$tree_sha" \
  --arg report_path 'target/jankurai/repo-score.json' \
  --arg report_sha "$report_sha" \
  --arg report_fingerprint "$report_fingerprint" \
  --arg input_fingerprint "$input_fingerprint" \
  --arg policy_fingerprint "$policy_fingerprint" \
  --arg policy_path 'agent/audit-policy.toml' \
  --arg policy_sha "$policy_sha" \
  --argjson score "$score" \
  --argjson raw_score "$raw_score" \
  --argjson minimum_score "$minimum_score" \
  '{
    schema_version: $schema_version,
    repo: $repo,
    status: $status,
    head: $head,
    tree: $tree,
    report: {
      path: $report_path,
      sha256: $report_sha,
      report_fingerprint: $report_fingerprint,
      input_fingerprint: $input_fingerprint,
      policy_fingerprint: $policy_fingerprint,
      score: $score,
      raw_score: $raw_score,
      minimum_score: $minimum_score,
      caps_applied: [],
      hard_findings: 0
    },
    policy: {path: $policy_path, sha256: $policy_sha}
  }' > "$evidence_tmp"
chmod 0600 "$evidence_tmp"
mv -- "$evidence_tmp" target/jankurai/evidence.json
trap - EXIT
printf 'score ok\n'
