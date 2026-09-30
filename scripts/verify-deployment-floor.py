#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Dibas Sigdel
"""The deployment floor, asserted to be one number everywhere it is written.

Why this exists
---------------
The macOS deployment floor is written in three places that do not know about each
other: every ``XCBuildConfiguration`` in the Xcode project, the ``DEPLOYMENT_TARGET``
in ``scripts/package-release.sh``, and - once a build has run - the
``LSMinimumSystemVersion`` baked into the product. A fourth place, the published
appcast's ``<sparkle:minimumSystemVersion>``, is checked separately by
``verify-appcast.py``.

They drifted. The app target built at 26.6 while the two project-level
configurations said 26.0 and ``package-release.sh`` said 26.0 too, so the built
app carried ``LSMinimumSystemVersion = 26.6`` while the feed told Sparkle 26.0.
Every gate was green, because the appcast verifier asks "does the feed match the
floor that ``package-release.sh`` declares?" - and that declared value had
drifted from the real one. Sparkle offers an item to any system at or above the
declared minimum, so 26.0 through 26.5 were offered a build that cannot launch.

A gate that only checks the feed against a declared number cannot catch that,
however carefully written. This one compares the *sources* against each other, so
the declared number is the thing under test rather than the premise.

What it reads, and why not more
-------------------------------
Not the source ``NepalKit/Info.plist``: a hand-authored Info.plist carries the
unexpanded ``$(MACOSX_DEPLOYMENT_TARGET)`` token, so it does not record the floor
at all. That is the same fact ``verify-appcast.py`` records, and it is why that
script reads ``package-release.sh`` instead - and therefore why this script
exists to check the thing that script trusts.

Not the appcast: ``verify-appcast.py`` owns that comparison, and duplicating it
here would give two gates that can disagree.

The built product is checked when one is available and skipped when it is not, so
this runs in a clean checkout that has never been built. Under ``check-all.sh``
the build gate runs first, so it is always available there - which is the point:
a contributor running one command cannot miss it, while a contributor with no
build is not blocked by a gate about a build they do not have.
"""

from __future__ import annotations

import plistlib
import re
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
PROJECT = REPO_ROOT / "NepalKit.xcodeproj" / "project.pbxproj"
RELEASE_SCRIPT = REPO_ROOT / "scripts" / "package-release.sh"


def project_floors(text: str) -> list[tuple[int, str]]:
    """Every ``MACOSX_DEPLOYMENT_TARGET`` in an XCBuildConfiguration block.

    Returns (line number, value) so a failure can name the line to edit rather
    than making the reader search the file. Blocks without the key are skipped
    rather than treated as 26.0: an absent key means "inherit", and the project
    level is where inheritance is resolved, so an absent key is not a floor
    anyone ships.
    """
    lines = text.splitlines()
    found: list[tuple[int, str]] = []
    index = 0
    while index < len(lines):
        if "isa = XCBuildConfiguration;" not in lines[index]:
            index += 1
            continue
        end = index
        while end < len(lines) and "};" not in lines[end]:
            end += 1
        for offset in range(index, min(end, len(lines))):
            match = re.search(r"MACOSX_DEPLOYMENT_TARGET = ([0-9.]+);", lines[offset])
            if match:
                found.append((offset + 1, match.group(1)))
        index = end + 1
    return found


def release_script_floor(text: str) -> tuple[int, str] | None:
    """``DEPLOYMENT_TARGET`` from package-release.sh, which the build is given.

    This is the value ``verify-appcast.py`` trusts, so it is the one that has to
    agree with the project or that gate is comparing the feed against a fiction.
    """
    for number, line in enumerate(text.splitlines(), start=1):
        match = re.match(r"^DEPLOYMENT_TARGET=(\S+)", line)
        if match:
            return number, match.group(1)
    return None


def product_floor(plist_path: Path) -> str | None:
    """``LSMinimumSystemVersion`` from a built product, or None if unreadable.

    Read with ``plistlib`` rather than by text-matching the plist, because the
    source plist and a built one are the same file only until Xcode expands the
    deployment-target token during the copy phase - and a text search over the
    source would happily return the unexpanded ``$(MACOSX_DEPLOYMENT_TARGET)``
    and call it a value.
    """
    try:
        with plist_path.open("rb") as handle:
            info = plistlib.load(handle)
    except (OSError, plistlib.InvalidFileException):
        return None
    value = info.get("LSMinimumSystemVersion")
    return value if isinstance(value, str) else None


def declared_floors() -> tuple[list[tuple[str, str]], str | None]:
    """(every floor, problem) - a problem string means the check cannot run.

    Reported as a value rather than raised, so a failure comes out in the same
    format as a disagreement and on stdout. An earlier version raised SystemExit
    with the message, which sends it to stderr and out of step with every other
    line this gate prints - a gate people have to read should not split its own
    report across two streams depending on which failure it was.

    The built product is only present once something has been built; its absence
    is not a disagreement, so it is simply not in the list.
    """
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


# The highest object version the CI toolchain can read. CI runs on the
# `xcode-27` image, whose Xcode writes and reads 110, so 110 is the correct
# version for this repository and a gate that rejected it would only be fighting
# the tool - Xcode rewrites the format every time it opens the project, so a
# maintainer editing build settings would be fighting the gate on every commit.
#
# The check is still worth having, for the next time the format moves. It has
# bitten twice, and both times the failure arrived as a red build on a pull
# request whose code was fine:
#
#     xcodebuild: error: Unable to read project 'NepalKit.xcodeproj'.
#     Reason: The project cannot be opened because it is in a future Xcode
#     project file format (110).
#
# That message names neither the setting nor the file to change, which is why the
# check lives here where it can say both. A future Xcode adopting a new format
# raises this ceiling, and raising it is the ADR-0007 re-evaluation: CI's
# toolchain has to move at the same time, or this gate fails on the pull request
# that made the move instead of on the change that should have prompted it.
MAX_OBJECT_VERSION = 110


def _project_format_problem(text: str) -> str | None:
    """A project file newer than CI's toolchain can read, if so.

    A project CI cannot open fails before it reaches the app's code, so this is
    checked where the message can name the setting, the ceiling, and the policy -
    rather than in a CI log, where the message is only about a project file.
    """
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
        "newer format has - move CI's Xcode floor up in the same change. "
        "ADR-0007 records that raising the floor is a re-evaluation of the "
        "deployment-floor claim, not a routine bump."
    )


def _locate_built_product() -> Path | None:
    """A built Info.plist, from the environment or the gate's own build.

    ``NEPAKIT_BUILT_PLIST`` is what ``run-app-tests.sh`` uses and what CI exports,
    so honouring it means this gate and the plist tests read the same product. The
    fallback is the path ``check-all.sh`` builds into, so a contributor who just
    ran the one command gets the check without setting anything.
    """
    import os

    from_env = os.environ.get("NEPAKIT_BUILT_PLIST")
    if from_env and Path(from_env).is_file():
        return Path(from_env)
    fallback = (
        REPO_ROOT / "DerivedData" / "Build" / "Products" / "Debug"
        / "NepalKit.app" / "Contents" / "Info.plist"
    )
    return fallback if fallback.is_file() else None


def main() -> int:
    try:
        declared, problem = declared_floors()
    except FileNotFoundError as error:
        print(f"FAIL  {error.filename} is missing, so the floor cannot be checked.")
        return 1

    if problem is not None:
        print(f"FAIL  {problem}")
        return 1

    if not declared:
        print("FAIL  no deployment target is declared anywhere.")
        return 1

    if problem is not None:
        print(f"FAIL  {problem}")
        return 1

    values = {value for _, value in declared}
    if len(values) == 1:
        floor = declared[0][1]
        print(f"Verifying the deployment floor is consistent everywhere")
        for source, value in declared:
            print(f"  ok    {source}: {value}")
        print(f"Deployment floor is {floor} everywhere it is written.")
        return 0

    # Every disagreeing source is named, not just the first. A reader who fixes
    # one and re-runs should not have to come back for the next, and the list is
    # the evidence that the drift was real rather than a single bad edit.
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
        "  signature. ADR-0003 records why this gate exists."
    )
    return 1


if __name__ == "__main__":
    sys.exit(main())
