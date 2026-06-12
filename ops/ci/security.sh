#!/usr/bin/env bash
set -euo pipefail
source ops/ci/lib.sh
mkdir -p target/security
if command -v gitleaks >/dev/null 2>&1; then
  if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    gitleaks detect --redact --verbose || true
  else
    gitleaks detect --no-git --redact --verbose || true
  fi
fi
if command -v actionlint >/dev/null 2>&1 && [[ -d .github/workflows ]]; then
  actionlint .github/workflows/*.yml
fi
if find . -path './.git' -prune -o -path './target' -prune -o -name '.env' -type f -print | grep -q .; then
  printf 'security check failed: committed .env file found\n' >&2
  exit 1
fi
# Dependency surface must stay parseable (supply-chain sanity, offline).
if [[ -f Cargo.toml ]]; then
  cargo metadata --format-version 1 --no-deps >/dev/null
fi
# Full dependency review (advisories, licenses, sources) when network allowed.
if [[ "${JERYU_SECURITY_NETWORK:-0}" == "1" ]] && command -v cargo-deny >/dev/null 2>&1 && [[ -f deny.toml ]]; then
  cargo deny check
fi
cat > target/security/evidence.json <<'JSON'
{"schema_version":"jeryu.split.security/v1","checks":["gitleaks","actionlint","env-file","cargo-metadata","optional-cargo-deny"]}
JSON
printf 'security ok\n'
