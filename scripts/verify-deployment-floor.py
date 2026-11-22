#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Dibas Sigdel
"""Check that the deployment floor is the same everywhere it is written.

macOS: every MACOSX_DEPLOYMENT_TARGET in the Xcode project, DEPLOYMENT_TARGET
in scripts/package-release.sh, and LSMinimumSystemVersion in a built product
if one is available. The appcast is checked by verify-appcast.py.

watchOS: every WATCHOS_DEPLOYMENT_TARGET in a block with its own
`SDKROOT = watchos` must agree, and NepalKitCore/Package.swift's watchOS
platform must not exceed it.

Usage: python3 scripts/verify-deployment-floor.py
"""

from __future__ import annotations

import plistlib
import re
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
PROJECT = REPO_ROOT / "NepalKit.xcodeproj" / "project.pbxproj"
RELEASE_SCRIPT = REPO_ROOT / "scripts" / "package-release.sh"
PACKAGE = REPO_ROOT / "NepalKitCore" / "Package.swift"

WATCHOS_SDKROOT = re.compile(r"^\s*SDKROOT = watchos;")
WATCHOS_TARGET = re.compile(r"WATCHOS_DEPLOYMENT_TARGET = ([0-9.]+);")


def _configuration_blocks(text: str) -> list[tuple[int, list[str]]]:
    """(index of the ``isa`` line, the block's lines) for each
    XCBuildConfiguration block, up to the ``};`` closing ``buildSettings``."""
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


def project_floors(text: str) -> list[tuple[int, str]]:
    """Every ``MACOSX_DEPLOYMENT_TARGET`` in an XCBuildConfiguration block,
    as (line number, value). Blocks without the key inherit and are skipped."""
    found: list[tuple[int, str]] = []
    for start, body in _configuration_blocks(text):
        for offset, line in enumerate(body, start=start):
            match = re.search(r"MACOSX_DEPLOYMENT_TARGET = ([0-9.]+);", line)
            if match:
                found.append((offset + 1, match.group(1)))
    return found


def watchos_project_floors(text: str) -> list[tuple[int, str]]:
    """Every ``WATCHOS_DEPLOYMENT_TARGET`` in a block declaring ``SDKROOT = watchos``.

    Only blocks with their own ``SDKROOT = watchos`` count: the macOS app target
    carries a leftover template key, and the iOS-side watch container is not a
    watchOS target. This assumes every watchOS target sets its own ``SDKROOT``.
    """
    found: list[tuple[int, str]] = []
    for start, body in _configuration_blocks(text):
        if not any(WATCHOS_SDKROOT.search(line) for line in body):
            continue
        for offset, line in enumerate(body, start=start):
            match = WATCHOS_TARGET.search(line)
            if match:
                found.append((offset + 1, match.group(1)))
    return found


def package_watchos_floor(text: str) -> tuple[int, str] | None:
    """The watchOS platform version in ``NepalKitCore/Package.swift``, as
    (line number, version), or None. ``//`` comments are ignored."""
    for number, line in enumerate(text.splitlines(), start=1):
        code = line.split("//", 1)[0]
        match = re.search(r"\.watchOS\(\.v([0-9.]+)\)", code)
        if match:
            return number, match.group(1)
    return None


def _version(value: str) -> tuple[int, ...]:
    """A dotted version as a comparable tuple: ``26.6`` -> ``(26, 6)``."""
    return tuple(int(part) for part in value.split("."))


def release_script_floor(text: str) -> tuple[int, str] | None:
    """``DEPLOYMENT_TARGET`` from package-release.sh, the value the build uses."""
    for number, line in enumerate(text.splitlines(), start=1):
        match = re.match(r"^DEPLOYMENT_TARGET=(\S+)", line)
        if match:
            return number, match.group(1)
    return None


def product_floor(plist_path: Path) -> str | None:
    """``LSMinimumSystemVersion`` from a built product, or None if unreadable."""
    try:
        with plist_path.open("rb") as handle:
            info = plistlib.load(handle)
    except (OSError, plistlib.InvalidFileException):
        return None
    value = info.get("LSMinimumSystemVersion")
    return value if isinstance(value, str) else None


def declared_floors() -> tuple[list[tuple[str, str]], str | None]:
    """(every macOS floor, problem); a problem string means the check cannot run."""
    declared: list[tuple[str, str]] = []
    for line, value in project_floors(PROJECT.read_text(encoding="utf-8")):
        declared.append((f"{PROJECT.name}:{line}", value))
    script = release_script_floor(RELEASE_SCRIPT.read_text(encoding="utf-8"))
    if script is None:
        return declared, (
            f"{RELEASE_SCRIPT.name} declares no DEPLOYMENT_TARGET. "
            "verify-appcast.py reads the floor from this file, so without it the "
            "appcast gate compares the feed against nothing."
        )
    declared.append((f"{RELEASE_SCRIPT.name}:{script[0]}", script[1]))
    plist_path = _locate_built_product()
    if plist_path is not None:
        built = product_floor(plist_path)
        if built is not None:
            declared.append((f"built product {plist_path.parent.name}", built))
    problem = _project_format_problem(PROJECT.read_text(encoding="utf-8"))
    return declared, problem


def watchos_declared_floors() -> tuple[list[tuple[str, str]], tuple[int, str] | None, str | None]:
    """(watchOS floors, package's watchOS floor, problem).

    The package floor only has to be <= the app's, not equal to it.
    """
    text = PROJECT.read_text(encoding="utf-8")
    declared = [(f"{PROJECT.name}:{line}", value)
                for line, value in watchos_project_floors(text)]
    if not declared:
        return declared, None, None
    try:
        package = package_watchos_floor(PACKAGE.read_text(encoding="utf-8"))
    except FileNotFoundError as error:
        return declared, None, f"{error.filename} is missing."
    if package is None:
        return declared, None, (
            f"{PACKAGE.name} declares no watchOS platform, so there is nothing to "
            "compare the app's watchOS floor against. Without it a package floor "
            "above the app's would go unnoticed, and the app would be built "
            "against a library that requires a newer watch than the app claims "
            "to support."
        )
    return declared, package, None


# The newest project format CI's Xcode can read. Older toolchains fail with an
# unhelpful "future Xcode project file format" error, so it is checked here.
# Raise it together with CI's Xcode.
MAX_OBJECT_VERSION = 110


def _project_format_problem(text: str) -> str | None:
    """A message if the project file is newer than CI's toolchain can read."""
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
    """A built Info.plist from ``NEPAKIT_BUILT_PLIST``, or check-all.sh's build."""
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
    """Repo-relative when the path is inside the repo, else as given."""
    try:
        return str(path.relative_to(REPO_ROOT))
    except ValueError:
        return str(path)


def main() -> int:
    try:
        declared, problem = declared_floors()
        watch_declared, package, watch_problem = watchos_declared_floors()
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

    if watch_problem is not None:
        print(f"FAIL  {watch_problem}")
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

    if watch_declared and package is not None:
        assert watch_values
        app_floor = watch_values.pop()
        if _version(package[1]) > _version(app_floor):
            print(
                f"FAIL  {PACKAGE.name}:{package[0]} declares a watchOS floor of "
                f"{package[1]}, which is higher than the {app_floor} the app's "
                "watchOS targets declare."
            )
            print(
                f"\n  NepalKitCore's watchOS platform is the *library's* compile\n"
                f"  floor, so it is allowed to be lower than the app's product\n"
                f"  claim - but not higher.\n"
                f"\n"
                f"  The consequence is an availability one, and it is a runtime\n"
                f"  failure rather than a build failure: core code compiled\n"
                f"  against a newer watchOS than the app claims can reference\n"
                f"  API that does not exist on the floor the app actually ships,\n"
                f"  so it builds cleanly here and then fails on an older watch.\n"
                f"\n"
                f"  Raise every watchOS target in the project to {package[1]} or\n"
                f"  above, or lower {PACKAGE.name}'s watchOS platform to the newest\n"
                f"  platform at or below {app_floor} that the manifest can express.\n"
                f"  Note that the manifest API's watchOS versions are discrete\n"
                f"  cases: an arbitrary version such as 26.6 is rejected outright\n"
                f"  while the manifest is compiled, so \"exactly {app_floor}\" is\n"
                f"  usually not an available answer."
            )
            return 1
        print(f"Deployment floors are consistent: macOS {floor}, "
              f"watchOS {app_floor} (package floor {package[1]}).")
    else:
        print(f"Deployment floor is {floor} everywhere it is written.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
