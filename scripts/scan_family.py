#!/usr/bin/env python3
"""Scan EVERY repo in the family for cross-repo repeated-code clusters.

This is the jeryu-tool-finder hot path. It drives the jeryu-codegraph engine's
`tool-build scan-family` subcommand (which folds every repo into one fingerprint
index) and writes the ranked cross-repo clusters to dossiers/clusters.json for
dossier.py to enrich.

The engine is invoked as a BINARY at runtime — jeryu-tool-finder takes no Cargo
dependency on jeryu-codegraph, so the family pin graph is unchanged. We look for
a prebuilt `jeryu-codegraph` binary first and fall back to `cargo run` in the
jeryu-intelligence checkout.

  scripts/scan_family.py --top 50 --min-repos 2
"""
from __future__ import annotations

import argparse
import json
import os
import shutil
import subprocess
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
SPLIT_ROOT = REPO_ROOT.parent
DEFAULT_MANIFEST = SPLIT_ROOT / "repos.manifest.toml"
DEFAULT_INTELLIGENCE = SPLIT_ROOT / "jeryu-intelligence"
DEFAULT_DB = Path(
    os.environ.get(
        "JERYU_CODEGRAPH_DB",
        Path.home() / ".local" / "share" / "jeryu" / "codegraph.sqlite",
    )
)
DEFAULT_OUT = REPO_ROOT / "dossiers" / "clusters.json"


def _resolve_engine(intelligence: Path) -> tuple[list[str], Path | None]:
    """Return (argv-prefix, cwd) for invoking the codegraph engine."""
    env_bin = os.environ.get("JERYU_CODEGRAPH_BIN")
    if env_bin and Path(env_bin).exists():
        return [env_bin], None
    on_path = shutil.which("jeryu-codegraph")
    if on_path:
        return [on_path], None
    for profile in ("release", "debug"):
        candidate = intelligence / "target" / profile / "jeryu-codegraph"
        if candidate.exists():
            return [str(candidate)], None
    # Last resort: compile-and-run from the intelligence checkout.
    if (intelligence / "Cargo.toml").exists():
        return ["cargo", "run", "-q", "-p", "jeryu-codegraph", "--"], intelligence
    raise SystemExit(
        "could not find a jeryu-codegraph engine: set JERYU_CODEGRAPH_BIN, put it "
        f"on PATH, or provide --intelligence (looked under {intelligence})"
    )


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--manifest", type=Path, default=DEFAULT_MANIFEST)
    parser.add_argument("--intelligence", type=Path, default=DEFAULT_INTELLIGENCE)
    parser.add_argument("--db", type=Path, default=DEFAULT_DB)
    parser.add_argument("--repo-id", default="family/jeryu-split")
    parser.add_argument("--top", type=int, default=50)
    parser.add_argument("--min-repos", type=int, default=2)
    parser.add_argument("--window-lines", type=int, default=8)
    parser.add_argument("--min-occurrences", type=int, default=2)
    parser.add_argument("--out", type=Path, default=DEFAULT_OUT)
    args = parser.parse_args(argv[1:])

    if not args.manifest.exists():
        raise SystemExit(f"manifest not found: {args.manifest}")
    args.db.parent.mkdir(parents=True, exist_ok=True)
    args.out.parent.mkdir(parents=True, exist_ok=True)

    prefix, cwd = _resolve_engine(args.intelligence)
    cmd = prefix + [
        "tool-build",
        "scan-family",
        "--manifest", str(args.manifest),
        "--db", str(args.db),
        "--repo-id", args.repo_id,
        "--top", str(args.top),
        "--min-repos", str(args.min_repos),
        "--window-lines", str(args.window_lines),
        "--min-occurrences", str(args.min_occurrences),
        "--json",
    ]
    print(f"[scan_family] {' '.join(cmd)}", file=sys.stderr)
    result = subprocess.run(cmd, cwd=cwd, capture_output=True, text=True)
    if result.returncode != 0:
        sys.stderr.write(result.stderr)
        raise SystemExit(f"engine failed (exit {result.returncode})")

    report = json.loads(result.stdout)
    args.out.write_text(json.dumps(report, indent=2, sort_keys=True))
    clusters = report.get("clusters", [])
    print(
        f"[scan_family] {report.get('scanned_files', 0)} files across the family -> "
        f"{len(clusters)} cross-repo cluster(s) (min_repos={args.min_repos}) -> {args.out}"
    )
    for cluster in clusters[:10]:
        print(
            f"  {cluster['cluster_id']} {cluster['language']} "
            f"repos={cluster['repo_count']} occ={cluster['occurrence_count']} "
            f"score={cluster['score']}"
        )
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
