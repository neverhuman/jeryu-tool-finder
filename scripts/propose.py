#!/usr/bin/env python3
"""Promote a finder dossier into a jeryu-tool proposal: a registry entry + a build task.

This is the hand-off that closes the loop. Given a cluster an agent judged worth
extracting, it appends a `[[tool]]` (status=proposed) to the sibling jeryu-tool's
tools-registry.toml and writes a tasks/NNNN-*.toml build task with a per-repo
rollout stub. It is idempotent on `origin_cluster`: re-proposing the same cluster
is a no-op.

  scripts/propose.py toolbuild-de0a62ca2b0b88c8
  scripts/propose.py toolbuild-de0a62ca2b0b88c8 --tool-id repo-settings-ts --dry-run
"""
from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path

try:
    import tomllib
except ModuleNotFoundError:  # Python < 3.11
    import tomli as tomllib  # type: ignore

REPO_ROOT = Path(__file__).resolve().parent.parent
SPLIT_ROOT = REPO_ROOT.parent
DEFAULT_JERYU_TOOL = SPLIT_ROOT / "jeryu-tool"
DEFAULT_DOSSIERS = REPO_ROOT / "dossiers" / "index.json"


def _slug(value: str) -> str:
    value = re.sub(r"[^a-z0-9]+", "-", value.lower()).strip("-")
    return value or "tool"


def _load_dossier(path: Path, cluster_id: str) -> dict:
    if not path.exists():
        raise SystemExit(f"dossiers not found: {path} (run scripts/dossier.py first)")
    for dossier in json.loads(path.read_text()):
        if dossier["cluster_id"] == cluster_id:
            return dossier
    raise SystemExit(f"cluster {cluster_id!r} not found in {path}")


def _toml_list(items: list[str]) -> str:
    if not items:
        return "[]"
    inner = ",\n".join(f'  "{item}"' for item in items)
    return "[\n" + inner + ",\n]"


def _next_task_index(tasks_dir: Path) -> int:
    highest = 0
    for path in tasks_dir.glob("*.toml"):
        match = re.match(r"(\d+)", path.name)
        if match:
            highest = max(highest, int(match.group(1)))
    return highest + 1


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("cluster_id")
    parser.add_argument("--jeryu-tool", type=Path, default=DEFAULT_JERYU_TOOL)
    parser.add_argument("--dossiers", type=Path, default=DEFAULT_DOSSIERS)
    parser.add_argument("--tool-id", default=None)
    parser.add_argument("--name", default=None)
    parser.add_argument("--kind", default=None)
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args(argv[1:])

    dossier = _load_dossier(args.dossiers, args.cluster_id)
    registry_path = args.jeryu_tool / "tools-registry.toml"
    tasks_dir = args.jeryu_tool / "tasks"
    if not registry_path.exists():
        raise SystemExit(f"registry not found: {registry_path}")

    registry = tomllib.loads(registry_path.read_text())
    for tool in registry.get("tool", []):
        if tool.get("origin_cluster") == args.cluster_id:
            print(f"already proposed: tool {tool['id']!r} <- cluster {args.cluster_id}")
            return 0

    tool_id = _slug(args.tool_id or dossier["suggested_name"])
    existing_ids = {tool["id"] for tool in registry.get("tool", [])}
    if tool_id in existing_ids:
        raise SystemExit(f"tool id {tool_id!r} already exists; pass a distinct --tool-id")

    name = args.name or dossier["suggested_name"]
    kind = args.kind or dossier["suggested_kind"]
    candidate_repos = dossier["candidate_repos"]
    estimate = int(dossier["anticipated_loc_saved"])
    task_index = _next_task_index(tasks_dir) if tasks_dir.is_dir() else 1
    task_id = f"{task_index:04d}"

    tool_block = (
        "\n"
        f"# Proposed by jeryu-tool-finder from cluster {args.cluster_id}.\n"
        "[[tool]]\n"
        f'id = "{tool_id}"\n'
        f'name = "{name}"\n'
        f'kind = "{kind}"\n'
        'status = "proposed"\n'
        'source = ""\n'
        f'description = "{dossier.get("insight", "").replace(chr(34), chr(39))}"\n'
        f'origin_cluster = "{args.cluster_id}"\n'
        "adopting_repos = []\n"
        f"candidate_repos = {_toml_list(candidate_repos)}\n"
        "loc_saved = 0\n"
        f"loc_saved_estimate = {estimate}\n"
    )

    task_text = (
        f"# tasks/{task_id}-{tool_id}.toml — filed by jeryu-tool-finder.\n\n"
        f'id = "{task_id}"\n'
        f'tool_id = "{tool_id}"\n'
        f'title = "Extract {name} into a shared {kind}"\n'
        'status = "open"\n'
        f'origin_cluster = "{args.cluster_id}"\n'
        f"anticipated_loc_saved = {estimate}\n"
        f"target_repos = {_toml_list(candidate_repos)}\n"
        "rollout = [\n"
        '  "Build the tool in its canonical home and tag it.",\n'
        '  "Replace each target repo\'s local copy with the shared tool.",\n'
        '  "Move migrated repos from candidate_repos to adopting_repos and grow loc_saved.",\n'
        '  "Confirm each repo\'s gate lanes stay green after the swap.",\n'
        "]\n"
    )

    task_path = tasks_dir / f"{task_id}-{tool_id}.toml"
    if args.dry_run:
        print(f"[dry-run] would append to {registry_path}:\n{tool_block}")
        print(f"[dry-run] would write {task_path}:\n{task_text}")
        return 0

    with registry_path.open("a") as fh:
        fh.write(tool_block)
    tasks_dir.mkdir(parents=True, exist_ok=True)
    task_path.write_text(task_text)
    print(f"proposed tool {tool_id!r} (+{estimate} LOC anticipated) <- cluster {args.cluster_id}")
    print(f"  registry: {registry_path}")
    print(f"  task:     {task_path}")
    print("Review, then run jeryu-tool's `just check` to validate.")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
