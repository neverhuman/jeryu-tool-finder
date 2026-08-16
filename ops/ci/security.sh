#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"
cd "$repo_root"
source "$repo_root/ops/ci/lib.sh"
for tool in git jq cargo gitleaks actionlint cargo-audit syft; do
  require_tool "$tool"
done

die() {
  printf 'security check failed: %s\n' "$*" >&2
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
  die 'source checkout must be clean before security proof'

prepare_dir target
prepare_dir target/security
clear_output target/security/evidence.json
clear_output target/security/cargo-audit.json
clear_output target/security/jeryu-tool-finder.spdx.json
if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  gitleaks detect --redact --verbose
else
  gitleaks detect --no-git --redact --verbose
fi
if [[ -d .github/workflows ]]; then
  actionlint .github/workflows/*.yml
fi
if find . -path './.git' -prune -o -path './target' -prune -o -name '.env' -type f -print | grep -q .; then
  printf 'security check failed: committed .env file found\n' >&2
  exit 1
fi
# Dependency surface must stay parseable (supply-chain sanity, offline).
if [[ -f Cargo.toml ]]; then
  cargo metadata --locked --offline --format-version 1 --no-deps >/dev/null
fi
# Full dependency review (advisories, licenses, sources) when network allowed.
if [[ "${JERYU_SECURITY_NETWORK:-0}" == "1" ]] && command -v cargo-deny >/dev/null 2>&1 && [[ -f deny.toml ]]; then
  cargo deny check
fi
cargo_audit_status="skipped-no-lock"
if [[ -f Cargo.lock ]]; then
  audit_tmp="$(mktemp "$repo_root/target/security/.cargo-audit.XXXXXX")"
  if cargo audit --no-fetch --format json > "$audit_tmp" 2>/dev/null; then
    cargo_audit_status="clean"
  else
    cargo_audit_status="findings-or-offline-db-unavailable"
  fi
  if jq -e 'type == "object"' "$audit_tmp" >/dev/null 2>&1; then
    chmod 0600 "$audit_tmp"
    mv -- "$audit_tmp" target/security/cargo-audit.json
  else
    rm -f -- "$audit_tmp"
    cargo_audit_status="invalid-output"
  fi
fi
sbom_status="skipped-tool-unavailable"
sbom_tmp="$(mktemp "$repo_root/target/security/.sbom.XXXXXX")"
if syft dir:. --exclude './target/**' --exclude './.git/**' \
  -o "spdx-json=$sbom_tmp" >/dev/null 2>&1 &&
  jq -e '.spdxVersion | startswith("SPDX-")' "$sbom_tmp" >/dev/null 2>&1; then
  sbom_status="generated"
  chmod 0600 "$sbom_tmp"
  mv -- "$sbom_tmp" target/security/jeryu-tool-finder.spdx.json
else
  sbom_status="generation-failed"
  rm -f -- "$sbom_tmp"
fi

[[ "$cargo_audit_status" == 'clean' ]] ||
  die "cargo audit prerequisite is not clean: $cargo_audit_status"
[[ "$sbom_status" == 'generated' ]] ||
  die "SPDX prerequisite was not generated: $sbom_status"

[[ "$(git rev-parse --verify HEAD)" == "$head_sha" ]] || die 'HEAD moved during security proof'
[[ "$(git rev-parse --verify 'HEAD^{tree}')" == "$tree_sha" ]] ||
  die 'tree moved during security proof'
[[ -z "$(git status --porcelain=v1 --untracked-files=all)" ]] ||
  die 'source checkout changed during security proof'

audit_sha=''
sbom_sha=''
if [[ -f target/security/cargo-audit.json && ! -L target/security/cargo-audit.json ]]; then
  [[ "$(stat -c '%h' target/security/cargo-audit.json)" -eq 1 ]] ||
    die 'cargo-audit evidence is multiply linked'
  audit_sha="$(sha256sum target/security/cargo-audit.json | awk '{print $1}')"
fi
if [[ -f target/security/jeryu-tool-finder.spdx.json && ! -L target/security/jeryu-tool-finder.spdx.json ]]; then
  [[ "$(stat -c '%h' target/security/jeryu-tool-finder.spdx.json)" -eq 1 ]] ||
    die 'SBOM evidence is multiply linked'
  sbom_sha="$(sha256sum target/security/jeryu-tool-finder.spdx.json | awk '{print $1}')"
fi

evidence_tmp="$(mktemp "$repo_root/target/security/.evidence.XXXXXX")"
trap 'rm -f -- "${evidence_tmp:-}"' EXIT
jq -nS \
  --arg schema_version 'jeryu.split.security/v1' \
  --arg repo 'jeryu-tool-finder' \
  --arg status 'pass' \
  --arg head "$head_sha" \
  --arg tree "$tree_sha" \
  --arg cargo_audit "$cargo_audit_status" \
  --arg sbom "$sbom_status" \
  --arg audit_path 'target/security/cargo-audit.json' \
  --arg audit_sha "$audit_sha" \
  --arg sbom_path 'target/security/jeryu-tool-finder.spdx.json' \
  --arg sbom_sha "$sbom_sha" \
  '{
    schema_version: $schema_version,
    repo: $repo,
    status: $status,
    head: $head,
    tree: $tree,
    checks: [
      "gitleaks-detect",
      "actionlint",
      "env-file",
      "cargo-metadata",
      "optional-cargo-deny",
      "cargo-audit-no-fetch",
      "syft-sbom"
    ],
    cargo_audit: $cargo_audit,
    sbom: $sbom,
    artifacts: {
      cargo_audit: {path: $audit_path, sha256: $audit_sha},
      sbom: {path: $sbom_path, sha256: $sbom_sha}
    }
  }' > "$evidence_tmp"
chmod 0600 "$evidence_tmp"
mv -- "$evidence_tmp" target/security/evidence.json
trap - EXIT
printf 'security ok\n'
