# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Dibas Sigdel
"""Build settings read from NepalKit.xcodeproj, the one place the floors are set."""

from __future__ import annotations

import re
from pathlib import Path

PROJECT = Path(__file__).resolve().parent.parent / "NepalKit.xcodeproj" / "project.pbxproj"

WATCHOS_SDKROOT = re.compile(r"^\s*SDKROOT = watchos;")
WATCHOS_TARGET = re.compile(r"WATCHOS_DEPLOYMENT_TARGET = ([0-9.]+);")
MACOS_TARGET = re.compile(r"MACOSX_DEPLOYMENT_TARGET = ([0-9.]+);")
SPARKLE_REFERENCE = re.compile(
    r'/\* XCRemoteSwiftPackageReference "Sparkle" \*/ = \{'
    r'((?:(?!/\* (?:XCRemoteSwiftPackageReference|End )).)*)',
    re.S)


def configuration_blocks(text: str) -> list[tuple[int, list[str]]]:
    lines = text.splitlines()
    blocks: list[tuple[int, list[str]]] = []
    index = 0
    while index < len(lines):
        if "isa = XCBuildConfiguration;" not in lines[index]:
            index += 1
            continue
        end = index
        while end < len(lines) and "};" not in lines[end]:
            end += 1
        blocks.append((index, lines[index:min(end, len(lines))]))
        index = end + 1
    return blocks


def macos_floors(text: str) -> list[tuple[int, str]]:
    """Every MACOSX_DEPLOYMENT_TARGET, as (line, value)."""
    found: list[tuple[int, str]] = []
    for start, body in configuration_blocks(text):
        for offset, line in enumerate(body, start=start):
            match = MACOS_TARGET.search(line)
            if match:
                found.append((offset + 1, match.group(1)))
    return found


def watchos_floors(text: str) -> list[tuple[int, str]]:
    """Every WATCHOS_DEPLOYMENT_TARGET in a block that sets SDKROOT = watchos."""
    found: list[tuple[int, str]] = []
    for start, body in configuration_blocks(text):
        if not any(WATCHOS_SDKROOT.search(line) for line in body):
            continue
        for offset, line in enumerate(body, start=start):
            match = WATCHOS_TARGET.search(line)
            if match:
                found.append((offset + 1, match.group(1)))
    return found


def macos_floor(project: Path = PROJECT) -> str | None:
    """The app's macOS floor, or None if the project declares none or several."""
    try:
        values = {value for _, value in macos_floors(project.read_text(encoding="utf-8"))}
    except OSError:
        return None
    return values.pop() if len(values) == 1 else None


def sparkle_pin(text: str) -> str:
    """The Sparkle version the project pins; SystemExit unless it is an exactVersion pin."""
    block = SPARKLE_REFERENCE.search(text)
    kind = block and re.search(r"kind = (\w+);", block.group(1))
    if not kind:
        raise SystemExit("no Sparkle package requirement found in project.pbxproj")
    version = re.search(r"version = ([\d.]+);", block.group(1))
    if kind.group(1) != "exactVersion" or not version:
        raise SystemExit(f"Sparkle pin kind is {kind.group(1)}, expected exactVersion")
    return version.group(1)


if __name__ == "__main__":
    import sys

    if sys.argv[1:] != ["sparkle-pin"]:
        raise SystemExit("usage: python3 scripts/xcode_project.py sparkle-pin")
    print(sparkle_pin(PROJECT.read_text(encoding="utf-8")))
