#!/usr/bin/env python3
"""Turn raw cross-repo clusters into rich, agent-readable tool-candidate dossiers.

A dossier is everything an LLM/agent needs to decide whether a cluster is worth
extracting into a shared tool: which repos and exact files carry the duplication,
a normalized preview, a suggested tool kind/name, and the anticipated LOC saved.

  scripts/dossier.py                       # reads dossiers/clusters.json
  scripts/dossier.py --input path.json
  scripts/dossier.py --selftest            # runs against fixtures/sample-clusters.json
"""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
DEFAULT_INPUT = REPO_ROOT / "dossiers" / "clusters.json"
DEFAULT_OUT_DIR = REPO_ROOT / "dossiers"
FIXTURE = REPO_ROOT / "fixtures" / "sample-clusters.json"

# Dominant scan language -> registry tool kind (see jeryu-tool docs/tools-registry.md).
KIND_BY_LANGUAGE = {
    "rust": "rust-crate",
    "typescript": "ts-lib",
    "javascript": "ts-lib",
    "typescript_react": "react-component",
    "javascript_react": "react-component",
    "shell": "shell-lib",
}


def _suggested_kind(language: str) -> str:
    return KIND_BY_LANGUAGE.get(language, "rust-crate")


def _window_span(cluster: dict) -> int:
    occ = cluster.get("occurrences") or []
    if not occ:
        return max(cluster.get("total_lines", 0), 1)
    first = occ[0]
    return max(int(first.get("end_line", 0)) - int(first.get("start_line", 0)) + 1, 1)


def _anchor_label(cluster: dict) -> str:
    """A short, human label mined from the normalized preview's call/macro anchors."""
    anchors = []
    for token in (cluster.get("normalized_preview") or "").split():
        if token.startswith(("call:", "macro:")):
            anchors.append(token.split(":", 1)[1])
        if len(anchors) >= 3:
            break
    return ", ".join(dict.fromkeys(anchors)) if anchors else cluster.get("language", "code")


def build_dossier(cluster: dict) -> dict:
    repos: dict[str, list[str]] = {}
    for occ in cluster.get("occurrences", []):
        repos.setdefault(occ["repo_id"], [])
        loc = f"{occ['path']}:{occ['start_line']}-{occ['end_line']}"
        if loc not in repos[occ["repo_id"]]:
            repos[occ["repo_id"]].append(loc)

    span = _window_span(cluster)
    anticipated = max(int(cluster.get("total_lines", 0)) - span, 0)
    candidate_repos = sorted(repos)
    kind = _suggested_kind(cluster.get("language", "unknown"))
    label = _anchor_label(cluster)

    return {
        "cluster_id": cluster["cluster_id"],
        "language": cluster.get("language", "unknown"),
        "repo_count": cluster.get("repo_count", len(candidate_repos)),
        "occurrence_count": cluster.get("occurrence_count", 0),
        "file_count": cluster.get("file_count", 0),
        "score": cluster.get("score", 0),
        "anticipated_loc_saved": anticipated,
        "suggested_kind": kind,
        "suggested_name": f"Shared {cluster.get('language', 'code')} helper ({label})",
        "candidate_repos": candidate_repos,
        "insight": cluster.get("insight", ""),
        "normalized_preview": cluster.get("normalized_preview", ""),
        "examples_by_repo": {repo: locs[:6] for repo, locs in sorted(repos.items())},
    }


def _render_markdown(d: dict) -> str:
    lines = [
        f"# Tool candidate: {d['cluster_id']}",
        "",
        f"- **suggested**: `{d['suggested_kind']}` — {d['suggested_name']}",
        f"- **spans**: {d['repo_count']} repo(s), {d['file_count']} file(s), "
        f"{d['occurrence_count']} occurrence(s)",
        f"- **anticipated LOC saved**: {d['anticipated_loc_saved']} (score {d['score']})",
        f"- **candidate repos**: {', '.join(d['candidate_repos'])}",
        "",
        f"_{d['insight']}_",
        "",
        "## Where it lives",
        "",
    ]
    for repo, locs in d["examples_by_repo"].items():
        lines.append(f"### {repo}")
        lines.extend(f"- `{loc}`" for loc in locs)
        lines.append("")
    lines += ["## Normalized window", "", "```", d["normalized_preview"], "```", ""]
    lines += [
        "## Decision",
        "",
        "If this is worth extracting, run:",
        "",
        "```bash",
        f"scripts/propose.py {d['cluster_id']}",
        "```",
        "",
        "which files a build task + a `proposed` entry into jeryu-tool's registry.",
        "",
    ]
    return "\n".join(lines)


def _load_clusters(path: Path) -> list[dict]:
    data = json.loads(path.read_text())
    if isinstance(data, dict):
        return data.get("clusters", [])
    return data


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--input", type=Path, default=DEFAULT_INPUT)
    parser.add_argument("--out-dir", type=Path, default=DEFAULT_OUT_DIR)
    parser.add_argument("--min-repos", type=int, default=2)
    parser.add_argument("--selftest", action="store_true")
    args = parser.parse_args(argv[1:])

    source = FIXTURE if args.selftest else args.input
    if not source.exists():
        raise SystemExit(f"clusters input not found: {source} (run scripts/scan_family.py first)")

    clusters = _load_clusters(source)
    dossiers = [
        build_dossier(c)
        for c in clusters
        if int(c.get("repo_count", 0)) >= args.min_repos
    ]
    dossiers.sort(key=lambda d: d["anticipated_loc_saved"], reverse=True)

    if args.selftest:
        assert dossiers, "selftest: fixture produced no cross-repo dossiers"
        top = dossiers[0]
        assert top["candidate_repos"], "selftest: dossier missing candidate repos"
        assert top["anticipated_loc_saved"] >= 0
        assert top["suggested_kind"] in {
            "rust-crate", "ts-lib", "react-component", "vite-plugin", "shell-lib",
        }
        print(f"dossier selftest ok: {len(dossiers)} dossier(s) from fixture")
        return 0

    out_dir = args.out_dir
    out_dir.mkdir(parents=True, exist_ok=True)
    (out_dir / "index.json").write_text(json.dumps(dossiers, indent=2, sort_keys=True))
    for d in dossiers:
        (out_dir / f"{d['cluster_id']}.md").write_text(_render_markdown(d))
    print(f"[dossier] wrote {len(dossiers)} dossier(s) -> {out_dir}")
    for d in dossiers[:10]:
        print(
            f"  {d['cluster_id']} {d['suggested_kind']} repos={d['repo_count']} "
            f"loc_saved~{d['anticipated_loc_saved']}"
        )
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
