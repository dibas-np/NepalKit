#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Dibas Sigdel
"""Usage: python3 scripts/verify-deployment-floor.py
"""

from __future__ import annotations

import plistlib
import re
import sys
from pathlib import Path

from xcode_project import macos_floors as project_floors
from xcode_project import watchos_floors as watchos_project_floors

REPO_ROOT = Path(__file__).resolve().parent.parent
PROJECT = REPO_ROOT / "NepalKit.xcodeproj" / "project.pbxproj"


def product_floor(plist_path: Path) -> str | None:
    try:
        with plist_path.open("rb") as handle:
            info = plistlib.load(handle)
    except (OSError, plistlib.InvalidFileException):
        return None
    value = info.get("LSMinimumSystemVersion")
    return value if isinstance(value, str) else None


def declared_floors() -> tuple[list[tuple[str, str]], str | None]:
    declared: list[tuple[str, str]] = []
    for line, value in project_floors(PROJECT.read_text(encoding="utf-8")):
        declared.append((f"{PROJECT.name}:{line}", value))
    plist_path = _locate_built_product()
    if plist_path is not None:
        built = product_floor(plist_path)
        if built is not None:
            declared.append((f"built product {plist_path.parent.name}", built))
    problem = _project_format_problem(PROJECT.read_text(encoding="utf-8"))
    return declared, problem


def watchos_declared_floors() -> list[tuple[str, str]]:
    text = PROJECT.read_text(encoding="utf-8")
    return [(f"{PROJECT.name}:{line}", value)
            for line, value in watchos_project_floors(text)]


MAX_OBJECT_VERSION = 110


def _project_format_problem(text: str) -> str | None:
    match = re.search(r"^\s*objectVersion = (\d+);", text, re.M)
    if match is None:
        return None
    version = int(match.group(1))
    if version <= MAX_OBJECT_VERSION:
        return None
    return (
        f"{PROJECT.name} is object version {version}, and CI runs on the "
        f"xcode-27 image, whose toolchain reads up to {MAX_OBJECT_VERSION}. "
        "A newer Xcode rewrites this format simply by opening the project, so it "
        "changes without an edit to it. Either set objectVersion back to "
        f"{MAX_OBJECT_VERSION}, or - if the project now needs a feature only the "
        "newer format has - move CI's Xcode floor up in the same change."
    )


def _locate_built_product() -> Path | None:
    import os

    from_env = os.environ.get("NEPAKIT_BUILT_PLIST")
    if from_env and Path(from_env).is_file():
        return Path(from_env)
    fallback = (
        REPO_ROOT / "DerivedData" / "Build" / "Products" / "Debug"
        / "NepalKit.app" / "Contents" / "Info.plist"
    )
    return fallback if fallback.is_file() else None


def _display_path(path: Path) -> str:
    try:
        return str(path.relative_to(REPO_ROOT))
    except ValueError:
        return str(path)


def main() -> int:
    try:
        declared, problem = declared_floors()
        watch_declared = watchos_declared_floors()
    except FileNotFoundError as error:
        print(f"FAIL  {error.filename} is missing, so the floor cannot be checked.")
        return 1

    if problem is not None:
        print(f"FAIL  {problem}")
        return 1

    if not declared:
        print("FAIL  no deployment target is declared anywhere.")
        return 1

    values = {value for _, value in declared}
    if len(values) == 1:
        floor = declared[0][1]
        print(f"Verifying the deployment floor is consistent everywhere")
        for source, value in declared:
            print(f"  ok    {source}: {value}")
        for source, value in watch_declared:
            print(f"  watchOS {source}: {value}")
    else:
        print("Deployment floor is NOT consistent. The floor is written in more than "
              "one place and these disagree:\n")
        for source, value in declared:
            print(f"  {source}: {value}")
        print(
            "\n  Sparkle offers an update to any system at or above the minimum the\n"
            "  feed declares, so a floor here that is lower than the app's real one\n"
            "  offers updates to systems that cannot launch the build. Fix every\n"
            "  source above to the same value, then re-sign appcast.xml if you moved\n"
            "  its <sparkle:minimumSystemVersion> - editing a feed invalidates its\n"
            "  signature."
        )
        return 1

    watch_values = {value for _, value in watch_declared}
    if watch_declared and len(watch_values) != 1:
        print("\nwatchOS deployment floor is NOT consistent. These watchOS targets "
              "disagree:\n")
        for source, value in watch_declared:
            print(f"  watchOS {source}: {value}")
        print(
            "\n  Every watchOS target in one product must make the same claim about\n"
            "  the oldest watch it supports: the Watch app, the complication\n"
            "  extension and the Watch test bundle ship as one product, and a user\n"
            "  cannot be given two answers. Set each of the sources above to the\n"
            "  same value. An extension requiring *more* than its app is the\n"
            "  direction known to break installation on older watches, so raise\n"
            "  the extension and test bundle to the app's floor rather than\n"
            "  lowering the app to theirs."
        )
        return 1

    if watch_declared:
        print(f"Deployment floors are consistent: macOS {floor}, "
              f"watchOS {watch_values.pop()}.")
    else:
        print(f"Deployment floor is {floor} everywhere it is written.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
