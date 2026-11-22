# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Dibas Sigdel
"""Refuse Sparkle tools that are not the pinned release before they touch the signing key.

The tools in DerivedData/SourcePackages/artifacts/sparkle/Sparkle/bin come from the
package resolved at checkouts/Sparkle. That checkout must be the revision and origin
Package.resolved pins, tagged at the project's exactVersion pin, and every tool must
resolve inside its own directory.

Usage: python3 scripts/sparkle_tools.py <tool>...
"""

from __future__ import annotations

import json
import subprocess
import sys
from pathlib import Path

from xcode_project import PROJECT, sparkle_pin

RESOLVED = PROJECT.parent / "project.xcworkspace" / "xcshareddata" / "swiftpm" / "Package.resolved"


def resolved_pin(resolved: Path = RESOLVED) -> tuple[str, str]:
    """The (location, revision) Package.resolved records for Sparkle."""
    pins = json.loads(resolved.read_text(encoding="utf-8"))["pins"]
    pin = next(p for p in pins if p["identity"] == "sparkle")
    return pin["location"], pin["state"]["revision"]


def _git(checkout: Path, *args: str) -> str:
    result = subprocess.run(["git", "-C", str(checkout), *args], capture_output=True, text=True)
    return result.stdout.strip() if result.returncode == 0 else ""


def _same_origin(a: str, b: str) -> bool:
    def norm(url: str) -> str:
        url = url.rstrip("/")
        return url[:-4] if url.endswith(".git") else url
    return norm(a) == norm(b)


def tool_problem(tool: Path, project: Path = PROJECT, resolved: Path = RESOLVED) -> str | None:
    """Why `tool` must not run, or None when it is the pinned Sparkle release."""
    if not tool.is_file():
        return f"no Sparkle tool at {tool}"
    tool_dir = tool.parent.resolve()
    if tool.resolve().parent != tool_dir:
        return f"{tool} resolves outside {tool_dir}"
    version = sparkle_pin(project.read_text(encoding="utf-8"))
    location, revision = resolved_pin(resolved)
    if len(tool_dir.parents) < 4:
        return f"{tool} is not inside a SourcePackages/artifacts tree"
    checkout = tool_dir.parents[3] / "checkouts" / "Sparkle"
    if not checkout.is_dir():
        return f"no Sparkle source checkout at {checkout}; cannot confirm {tool.name} is {version}"
    if _git(checkout, "rev-parse", "HEAD") != revision:
        return f"the Sparkle checkout is not at the pinned revision {revision}"
    if not _same_origin(_git(checkout, "remote", "get-url", "origin"), location):
        return f"the Sparkle checkout does not come from {location}"
    if _git(checkout, "describe", "--tags", "--exact-match") != version:
        return f"the Sparkle checkout is not tagged {version}"
    return None


if __name__ == "__main__":
    if len(sys.argv) < 2:
        raise SystemExit("usage: python3 scripts/sparkle_tools.py <tool>...")
    for path in sys.argv[1:]:
        problem = tool_problem(Path(path))
        if problem:
            raise SystemExit(f"refusing to run {Path(path).name}: {problem}")
    print(f"Sparkle tools are the pinned release: {' '.join(Path(p).name for p in sys.argv[1:])}")
