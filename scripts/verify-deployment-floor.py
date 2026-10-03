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

The watchOS floor, and why it is not the same check
---------------------------------------------------
The watchOS floor is a *second* floor, in a *second* set of blocks, and it is
compared separately rather than folded into the list above. A macOS value and a
watchOS value are never equal to each other, so collapsing them into one set would
make this gate permanently red and therefore useless.

The rule that decides which blocks are allowed to declare a watchOS floor is
**positive identification**: a block declares one if and only if it contains its
own ``SDKROOT = watchos``. That is chosen over the more obvious negative test
("anything that is not a macOS block") because the project contains three block
shapes, and only positive identification is correct for all three:

- ``SDKROOT = watchos`` - the Watch app, the complication extension and the Watch
  test bundle. These declare the product's watchOS floor.
- no ``SDKROOT`` of its own - the macOS app target, which inherits ``macosx``
  from the project level. It carried a ``WATCHOS_DEPLOYMENT_TARGET`` left over
  from Xcode's template; a macOS app embeds no watch content, so it declares no
  watchOS floor. A negative test excludes these, but only by coincidence.
- ``SDKROOT = iphoneos`` - the watchOS *container*, an iOS-side target that
  embeds the Watch app and declares an ``IPHONEOS_DEPLOYMENT_TARGET``. A negative
  test would wrongly classify it as a watchOS block.

Positive identification is safe here because every platform-specific target in
this project sets its own ``SDKROOT``, so no watchOS target inherits one and none
can be silently skipped. **That is the assumption this rule rests on.** If a
future target ever does inherit its ``SDKROOT``, this function will stop reading
it, and the gate will go quiet rather than wrong - so a new watchOS target must
declare its own ``SDKROOT``, as all six current ones do.

The recorded floor is compared with ``==`` rather than trusted: the validation
evidence doc states, in a toolchain-table row, the watchOS floor its results
were produced at, and this gate requires that value to equal the project's. The
26.6 interlude - a floor raised for two commits with every gate green - is why
this check exists: consistency between sources is not consistency between the
sources and the story told about them.

``NepalKitCore``'s manifest is compared with ``<=`` rather than ``==``: the
package's platform is the library's *compile* floor, while the app's deployment
target is a *product* claim about the oldest supported watch. They are allowed to
differ, and the only unsafe direction is the package requiring more than its
consumer. (The package cannot express 26.6 at all - the manifest API's watchOS
versions are discrete cases - so ``==`` would make this gate permanently red.)
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
EVIDENCE = REPO_ROOT / "docs" / "watch" / "readiness-evidence.md"

WATCHOS_SDKROOT = re.compile(r"^\s*SDKROOT = watchos;")
WATCHOS_TARGET = re.compile(r"WATCHOS_DEPLOYMENT_TARGET = ([0-9.]+);")


def _configuration_blocks(text: str) -> list[tuple[int, list[str]]]:
    """(index of the ``isa`` line, that line and the rest of its block) per block.

    Shared by both parsers so the two floors are read from exactly the same blocks.
    A block runs from its ``isa = XCBuildConfiguration;`` line to the ``};`` that
    closes ``buildSettings`` - which is every line either key can appear on.
    """
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
    """Every ``MACOSX_DEPLOYMENT_TARGET`` in an XCBuildConfiguration block.

    Returns (line number, value) so a failure can name the line to edit rather
    than making the reader search the file. Blocks without the key are skipped
    rather than treated as 26.0: an absent key means "inherit", and the project
    level is where inheritance is resolved, so an absent key is not a floor
    anyone ships.

    Every block is a candidate here - the macOS floor is the one this project has
    always declared in all of them - so this is deliberately *not* filtered by
    ``SDKROOT`` the way :func:`watchos_project_floors` is.
    """
    found: list[tuple[int, str]] = []
    for start, body in _configuration_blocks(text):
        for offset, line in enumerate(body, start=start):
            match = re.search(r"MACOSX_DEPLOYMENT_TARGET = ([0-9.]+);", line)
            if match:
                found.append((offset + 1, match.group(1)))
    return found


def watchos_project_floors(text: str) -> list[tuple[int, str]]:
    """Every ``WATCHOS_DEPLOYMENT_TARGET`` in a block declaring ``SDKROOT = watchos``.

    A block declares a watchOS floor **if and only if it contains its own
    ``SDKROOT = watchos``**. That is positive identification, and it is what makes
    this correct for all three block shapes the project contains: the watchOS
    blocks, the macOS app target that inherits its ``SDKROOT`` and carries a
    leftover template key, and the iOS-side watch container. A negative test
    ("anything that is not macOS") gets the first two right by accident and the
    third wrong.

    The assumption this rests on, and the one to re-check if a target is ever
    added: every platform-specific target sets its own ``SDKROOT``, so no watchOS
    target inherits one and none can be silently skipped. A watchOS target that
    inherited its ``SDKROOT`` would be invisible here - the gate would go quiet
    rather than wrong, which is the worse failure because it looks like a pass.

    Line numbers are returned for the same reason as in :func:`project_floors`:
    a failure should name the line to edit.
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


def evidence_recorded_floors(text: str) -> list[tuple[int, str]]:
    """The watchOS floor recorded in the validation evidence, with line numbers.

    The evidence record states the floor its results were produced at as a
    toolchain-table row of the form
    ``| watchOS floor (ratified 2026-10-04) | 26.0 |``. That row is the
    machine-readable half of the ratification record: the gate compares it
    with the project so a floor that moves without moving its record fails
    here instead of shipping green. The 26.6 interlude stayed green under
    every check precisely because nothing made that comparison.
    """
    return [
        (text[:match.start()].count("\n") + 1, match.group(1))
        for match in re.finditer(
            r"^\|\s*watchOS floor[^|\n]*\|\s*([0-9.]+)\s*\|\s*$",
            text,
            re.MULTILINE,
        )
    ]


def package_watchos_floor(text: str) -> tuple[int, str] | None:
    """The watchOS platform version declared in ``NepalKitCore/Package.swift``.

    Returns (line number, version) or None if the manifest declares no watchOS
    platform. Mirrors :func:`release_script_floor` for the manifest side of the
    same ``<=`` relation.

    ``//`` comments are stripped before matching. The manifest carries a comment
    explaining that 26.6 and 27 are both rejected by the manifest compiler, and a
    parser that read its own file's prose would invent a floor nobody declared -
    the exact quiet lie this gate exists to catch, turned on the gate itself.
    """
    for number, line in enumerate(text.splitlines(), start=1):
        code = line.split("//", 1)[0]
        match = re.search(r"\.watchOS\(\.v([0-9.]+)\)", code)
        if match:
            return number, match.group(1)
    return None


def _version(value: str) -> tuple[int, ...]:
    """A dotted version as a comparable tuple: ``26.6`` -> ``(26, 6)``.

    Compared as tuples rather than floats because ``26.10`` is a real version
    number and would compare below ``26.9`` as a float.
    """
    return tuple(int(part) for part in value.split("."))


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


def watchos_declared_floors() -> tuple[list[tuple[str, str]], tuple[int, str] | None, str | None]:
    """(watchOS floors, package's watchOS floor, problem) for the watchOS side.

    Separate from :func:`declared_floors` because this is a second floor that must
    be collapsed on its own: a macOS value and a watchOS value are never equal, so
    putting them in one set would make the gate permanently red.

    The package's floor is returned rather than folded into ``declared`` because
    it is not required to *equal* the app's floor - only not to exceed it. The
    asymmetry is legitimate: the package declares the core library's compile
    floor, while the app declares a product support claim.
    """
    text = PROJECT.read_text(encoding="utf-8")
    declared = [(f"{PROJECT.name}:{line}", value)
                for line, value in watchos_project_floors(text)]
    if not declared:
        # A project with no watchOS product declares no watchOS floor, which is
        # not a failure - there is nothing to be inconsistent about.
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


def _display_path(path: Path) -> str:
    """Short form for output: repo-relative when the path is inside the repo.

    The sandbox tests point this gate at files in temporary directories, so a
    bare ``relative_to`` would raise on exactly the paths the tests exercise.
    """
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

    if watch_problem is not None:
        print(f"FAIL  {watch_problem}")
        return 1

    watch_values = {value for _, value in watch_declared}
    if watch_declared and len(watch_values) != 1:
        # Deliberately does not claim this will fail App Review. The documented,
        # reproducible failure in this family runs the *other* way - an extension
        # whose floor is higher than its containing app makes the app uninstallable
        # on older watches - and this is the reverse. What is certain is that two
        # bundles in one product contradict each other about the oldest watch the
        # product supports, which is a bug whichever way it is resolved.
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
        if EVIDENCE.exists():
            recorded = evidence_recorded_floors(EVIDENCE.read_text(encoding="utf-8"))
        else:
            print(f"FAIL  {_display_path(EVIDENCE)} is missing, so the "
                  "watchOS floor the validation record describes cannot be "
                  "compared with the project's.")
            return 1
        if not recorded:
            print(
                f"FAIL  {_display_path(EVIDENCE)} does not record the "
                "watchOS floor its results were produced at.\n"
                "\n"
                "  Add a toolchain-table row of the form\n"
                "\n"
                "      | watchOS floor (ratified <date>) | <version> |\n"
                "\n"
                "  so this gate can prove the record and the project agree. The\n"
                "  26.6 interlude stayed green under every check because each\n"
                "  proved the sources agreed with each other and none compared\n"
                "  them with the record."
            )
            return 1
        recorded_values = {value for _, value in recorded}
        if recorded_values != {app_floor}:
            print(
                "FAIL  the watchOS floor the project declares and the one the "
                "validation record states disagree:\n"
            )
            for line, value in recorded:
                print(f"  watchOS {_display_path(EVIDENCE)}:{line}: {value}")
            print(
                f"  watchOS project.pbxproj (all watchOS targets): {app_floor}\n"
                "\n"
                "  The record is what a reader trusts when this gate passes, so a\n"
                "  floor that moved without its record moving is the drift the\n"
                "  26.6 interlude shipped. If the floor moved deliberately, update\n"
                "  the record's row in the same change; if only the record moved,\n"
                "  re-run the validation it describes before trusting it."
            )
            return 1
        print(f"  ok    {_display_path(EVIDENCE)}: {app_floor} (recorded)")
        print(f"Deployment floors are consistent: macOS {floor}, "
              f"watchOS {app_floor} (package floor {package[1]}).")
    else:
        print(f"Deployment floor is {floor} everywhere it is written.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
