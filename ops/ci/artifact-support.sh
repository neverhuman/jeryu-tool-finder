#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"
cd "$repo_root"

receipt_rel='target/artifact-support/jeryu-tool-finder.json'
receipt="$repo_root/$receipt_rel"

die() {
  printf 'artifact-support failed: %s\n' "$*" >&2
  exit 1
}

sha_file() {
  sha256sum "$1" | awk '{print $1}'
}

require_dir() {
  local relative="$1"
  local path="$repo_root/$relative"
  [[ -d "$path" && ! -L "$path" ]] || die "$relative is not a physical directory"
  [[ "$(realpath -e -- "$path")" == "$path" ]] || die "$relative escapes the repository"
}

require_file() {
  local relative="$1"
  local path="$repo_root/$relative"
  [[ -f "$path" && ! -L "$path" ]] || die "$relative is not a regular file"
  [[ "$(realpath -e -- "$path")" == "$path" ]] || die "$relative escapes the repository"
  [[ "$(stat -c '%h' "$path")" -eq 1 ]] || die "$relative is multiply linked"
}

require_clean_source() {
  [[ -z "$(git status --porcelain=v1 --untracked-files=all)" ]] ||
    die 'source checkout is not clean'
}

current_identity() {
  current_head="$(git rev-parse --verify HEAD)"
  current_tree="$(git rev-parse --verify 'HEAD^{tree}')"
  require_clean_source
}

validate_score() {
  local head="$1"
  local tree="$2"
  local evidence='target/jankurai/evidence.json'
  local report='target/jankurai/repo-score.json'
  local policy='agent/audit-policy.toml'
  local evidence_sha report_sha policy_sha floor

  require_dir target/jankurai
  require_file "$evidence"
  require_file "$report"
  require_file "$policy"
  evidence_sha="$(sha_file "$evidence")"
  report_sha="$(sha_file "$report")"
  policy_sha="$(sha_file "$policy")"
  floor="$(awk -F= '/^[[:space:]]*minimum_score[[:space:]]*=/ {
    gsub(/[[:space:]]/, "", $2); print $2; exit
  }' "$policy")"
  [[ "$floor" =~ ^[0-9]+$ ]] || die 'score policy floor is not an integer'

  jq -e --slurpfile raw "$report" --arg head "$head" --arg tree "$tree" \
    --arg report_sha "$report_sha" --arg policy_sha "$policy_sha" \
    --argjson floor "$floor" '
      .schema_version == "jeryu.split.score/v1" and
      .repo == "jeryu-tool-finder" and .status == "pass" and
      .head == $head and .tree == $tree and
      .report.path == "target/jankurai/repo-score.json" and
      .report.sha256 == $report_sha and
      .policy.path == "agent/audit-policy.toml" and .policy.sha256 == $policy_sha and
      (.report.score | type == "number") and .report.score >= $floor and
      .report.score == $raw[0].score and
      .report.raw_score == $raw[0].raw_score and
      .report.minimum_score == $floor and
      .report.caps_applied == [] and .report.hard_findings == 0 and
      .report.report_fingerprint == $raw[0].report_fingerprint and
      .report.input_fingerprint == $raw[0].input_fingerprint and
      .report.policy_fingerprint == $raw[0].policy_fingerprint and
      (.report.report_fingerprint | test("^sha256:[0-9a-f]{64}$")) and
      (.report.input_fingerprint | test("^sha256:[0-9a-f]{64}$")) and
      (.report.policy_fingerprint | test("^sha256:[0-9a-f]{64}$"))
    ' "$evidence" >/dev/null || die 'score evidence contract is not satisfied'

  jq -e --argjson floor "$floor" '
      (.score | type == "number") and .score >= $floor and
      ((.caps_applied // .caps // []) | length) == 0 and
      (((.decision // {}).hard_findings // .hard_findings // 0) as $hard |
        if ($hard | type) == "array" then ($hard | length) == 0 else $hard == 0 end) and
      ((.decision // {}).passed // true) == true
    ' "$report" >/dev/null || die 'raw score report is not release-ready'

  score_evidence_sha="$evidence_sha"
}

validate_security() {
  local head="$1"
  local tree="$2"
  local evidence='target/security/evidence.json'
  local audit='target/security/cargo-audit.json'
  local sbom='target/security/jeryu-tool-finder.spdx.json'
  local evidence_sha audit_sha sbom_sha

  require_dir target/security
  require_file "$evidence"
  require_file "$audit"
  require_file "$sbom"
  evidence_sha="$(sha_file "$evidence")"
  audit_sha="$(sha_file "$audit")"
  sbom_sha="$(sha_file "$sbom")"

  jq -e --arg head "$head" --arg tree "$tree" --arg audit_sha "$audit_sha" \
    --arg sbom_sha "$sbom_sha" '
      .schema_version == "jeryu.split.security/v1" and
      .repo == "jeryu-tool-finder" and .status == "pass" and
      .head == $head and .tree == $tree and
      .checks == [
        "gitleaks-detect", "actionlint", "env-file", "cargo-metadata",
        "optional-cargo-deny", "cargo-audit-no-fetch", "syft-sbom"
      ] and
      .cargo_audit == "clean" and .sbom == "generated" and
      .artifacts.cargo_audit.path == "target/security/cargo-audit.json" and
      .artifacts.cargo_audit.sha256 == $audit_sha and
      .artifacts.sbom.path == "target/security/jeryu-tool-finder.spdx.json" and
      .artifacts.sbom.sha256 == $sbom_sha
    ' "$evidence" >/dev/null || die 'security evidence contract is not release-ready'
  jq -e 'type == "object"' "$audit" >/dev/null || die 'cargo-audit evidence is not JSON'
  jq -e '(.spdxVersion | startswith("SPDX-")) and
         (.SPDXID | type == "string") and (.packages | type == "array")' \
    "$sbom" >/dev/null || die 'SBOM is not a valid SPDX document'

  security_evidence_sha="$evidence_sha"
}

validate_cli_contract() {
  local stdout_tmp stderr_tmp
  stdout_tmp="$(mktemp "$repo_root/target/artifact-support/.help.stdout.XXXXXX")"
  stderr_tmp="$(mktemp "$repo_root/target/artifact-support/.help.stderr.XXXXXX")"
  if ! target/release/jeryu-tool-finder --help > "$stdout_tmp" 2> "$stderr_tmp"; then
    rm -f -- "$stdout_tmp" "$stderr_tmp"
    die 'release CLI --help failed'
  fi
  if [[ -s "$stderr_tmp" ]] || ! cmp -s -- contracts/cli-help.txt "$stdout_tmp"; then
    rm -f -- "$stdout_tmp" "$stderr_tmp"
    die 'release CLI help does not match contracts/cli-help.txt'
  fi
  rm -- "$stdout_tmp" "$stderr_tmp"
}

validate_receipt() {
  local head tree binary_sha binary_size lock_sha contract_sha
  current_identity
  head="$current_head"
  tree="$current_tree"

  require_dir target
  require_dir target/artifact-support
  require_file "$receipt_rel"
  require_file target/release/jeryu-tool-finder
  require_file Cargo.lock
  require_file contracts/cli-help.txt
  validate_score "$head" "$tree"
  validate_security "$head" "$tree"

  [[ -x target/release/jeryu-tool-finder ]] || die 'release CLI is not executable'
  validate_cli_contract
  binary_sha="$(sha_file target/release/jeryu-tool-finder)"
  binary_size="$(stat -c '%s' target/release/jeryu-tool-finder)"
  lock_sha="$(sha_file Cargo.lock)"
  contract_sha="$(sha_file contracts/cli-help.txt)"

  jq -e --arg head "$head" --arg tree "$tree" --arg binary_sha "$binary_sha" \
    --argjson binary_size "$binary_size" --arg lock_sha "$lock_sha" \
    --arg contract_sha "$contract_sha" --arg score_sha "$score_evidence_sha" \
    --arg security_sha "$security_evidence_sha" '
      keys == ["artifact", "evidence", "head", "inputs", "repo", "schema_version", "status", "tree"] and
      .schema_version == "jeryu.split.artifact-support/v1" and
      .repo == "jeryu-tool-finder" and .status == "ready" and
      .head == $head and .tree == $tree and
      .artifact == {
        kind: "rust-cli",
        path: "target/release/jeryu-tool-finder",
        sha256: $binary_sha,
        size: $binary_size
      } and
      .inputs == {
        cargo_lock: {path: "Cargo.lock", sha256: $lock_sha},
        cli_help_contract: {path: "contracts/cli-help.txt", sha256: $contract_sha}
      } and
      .evidence == {
        score: {path: "target/jankurai/evidence.json", sha256: $score_sha},
        security: {path: "target/security/evidence.json", sha256: $security_sha}
      }
    ' "$receipt" >/dev/null || die 'artifact-support receipt does not bind current evidence'
}

produce_receipt() {
  local head tree binary_sha binary_size lock_sha contract_sha receipt_tmp

  if [[ ! -e target ]]; then
    mkdir -- target
  fi
  require_dir target
  if [[ ! -e target/artifact-support ]]; then
    mkdir -- target/artifact-support
  fi
  require_dir target/artifact-support

  if [[ -e "$receipt" || -L "$receipt" ]]; then
    require_file "$receipt_rel"
    rm -- "$receipt"
  fi

  current_identity
  head="$current_head"
  tree="$current_tree"
  validate_score "$head" "$tree"
  validate_security "$head" "$tree"
  require_file Cargo.lock
  require_file contracts/cli-help.txt

  cargo build --locked --offline --release --bin jeryu-tool-finder

  [[ "$(git rev-parse --verify HEAD)" == "$head" ]] || die 'HEAD moved during artifact build'
  [[ "$(git rev-parse --verify 'HEAD^{tree}')" == "$tree" ]] ||
    die 'tree moved during artifact build'
  require_clean_source
  require_file target/release/jeryu-tool-finder
  [[ -x target/release/jeryu-tool-finder ]] || die 'release CLI is not executable'

  binary_sha="$(sha_file target/release/jeryu-tool-finder)"
  binary_size="$(stat -c '%s' target/release/jeryu-tool-finder)"
  lock_sha="$(sha_file Cargo.lock)"
  contract_sha="$(sha_file contracts/cli-help.txt)"
  receipt_tmp="$(mktemp "$repo_root/target/artifact-support/.receipt.XXXXXX")"
  trap 'rm -f -- "${receipt_tmp:-}"' EXIT
  jq -nS \
    --arg schema_version 'jeryu.split.artifact-support/v1' \
    --arg repo 'jeryu-tool-finder' \
    --arg status 'ready' \
    --arg head "$head" \
    --arg tree "$tree" \
    --arg binary_sha "$binary_sha" \
    --argjson binary_size "$binary_size" \
    --arg lock_sha "$lock_sha" \
    --arg contract_sha "$contract_sha" \
    --arg score_sha "$score_evidence_sha" \
    --arg security_sha "$security_evidence_sha" \
    '{
      schema_version: $schema_version,
      repo: $repo,
      status: $status,
      head: $head,
      tree: $tree,
      artifact: {
        kind: "rust-cli",
        path: "target/release/jeryu-tool-finder",
        sha256: $binary_sha,
        size: $binary_size
      },
      inputs: {
        cargo_lock: {path: "Cargo.lock", sha256: $lock_sha},
        cli_help_contract: {path: "contracts/cli-help.txt", sha256: $contract_sha}
      },
      evidence: {
        score: {path: "target/jankurai/evidence.json", sha256: $score_sha},
        security: {path: "target/security/evidence.json", sha256: $security_sha}
      }
    }' > "$receipt_tmp"
  chmod 0600 "$receipt_tmp"
  mv -- "$receipt_tmp" "$receipt"
  trap - EXIT

  validate_receipt
  printf 'artifact-support ready: %s\n' "$receipt_rel"
}

case "$#:${1-}" in
  0:)
    produce_receipt
    ;;
  1:--validate-receipt)
    validate_receipt
    printf 'artifact-support receipt valid: %s\n' "$receipt_rel"
    ;;
  *)
    printf 'usage: artifact-support.sh [--validate-receipt]\n' >&2
    exit 2
    ;;
esac
