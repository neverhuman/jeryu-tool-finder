#!/usr/bin/env python3
"""Thin wrapper over jeryu-tool's registry summary, for the finder CLI/MCP surface.

Lets an operator (or the jeryu CLI/MCP) read the same golden-box numbers the forge
serves, without depending on the running web edge. Delegates to the authoritative
implementation in the sibling jeryu-tool repo.

  scripts/registry_summary.py            # JSON summary
  scripts/registry_summary.py --check    # validate only
"""
from __future__ import annotations

import subprocess
import sys
from pathlib import Path

SPLIT_ROOT = Path(__file__).resolve().parent.parent.parent
JERYU_TOOL_SUMMARY = SPLIT_ROOT / "jeryu-tool" / "ops" / "registry_summary.py"


def main(argv: list[str]) -> int:
    if not JERYU_TOOL_SUMMARY.exists():
        raise SystemExit(f"jeryu-tool registry summary not found: {JERYU_TOOL_SUMMARY}")
    return subprocess.run([sys.executable, str(JERYU_TOOL_SUMMARY), *argv[1:]]).returncode


if __name__ == "__main__":
    sys.exit(main(sys.argv))
