#!/usr/bin/env python3
"""Measure and record Swift coverage for both test suites.

    scripts/measure-coverage.py            # measure, compare to the floor, report
    scripts/measure-coverage.py --update   # accept the current numbers as the floor

Two suites, measured separately and summed, because they compile different code
through different harnesses:

* ``NepalKitCore`` via ``swift test``. The calendar engine.
* ``scripts/apptests`` via ``swift test``. The app layer, whose harness symlinks
  the real ``NepalKit/`` and ``NepalKitTests/`` directories - see ADR-0005.

Why a script rather than a reading of the number: coverage that is measured by
hand is coverage that rots. This records a floor and fails when the number drops
below it, which is the part that stops silently.

**This gate deliberately has no target.** The OpenSSF badge asks for 80% and 90%
statement coverage; the combined figure is recorded in scripts/coverage-floor.json
and the gap is not a chore. See docs/coverage.md for why the SwiftUI layer is the blocker and what
closing it would actually require. A floor that ratchets upward as tests land
is honest; a target set above the truth is a lie that fails every day.

Offline and credential-free, like every other gate here: coverage needs a
toolchain and nothing else.
"""

from __future__ import annotations

import argparse
import fcntl
import hashlib
import json
import os
import shutil
import subprocess
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
FLOOR_FILE = REPO_ROOT / "scripts" / "coverage-floor.json"

# Only these count. Test files are the instrument, not the subject; counting them
# inflates the number by tens of points and makes the measurement useless.
#
# Matched against the path *relative to the repository root*, never against an
# absolute prefix. An earlier version hard-coded `/Projects/NepalKit/NepalKit/`,
# which silently matched nothing in a worktree or a CI checkout at a different
# path - and a coverage script that reports on zero files is worse than none,
# because it looks like it ran.
def subject_files(stdout: str, prefixes: tuple[str, ...]) -> list[str]:
    """Return the report rows whose file is product source under ``prefixes``."""
    keep = []
    # llvm-cov prints report paths with the leading "/" stripped, so both sides
    # are normalised before comparing. Comparing raw strings silently matches
    # nothing, which looks identical to "no product source was compiled".
    root = str(REPO_ROOT).lstrip("/") + "/"
    for line in stdout.splitlines():
        parts = line.split()
        if len(parts) != 13 or not parts[0].startswith(root):
            continue
        relative = parts[0][len(root):]
        if any(relative.startswith(prefix) for prefix in prefixes):
            keep.append(line)
    return keep


def summarise(report_text: str, prefixes: tuple[str, ...]) -> dict[str, int]:
    """Total the raw counts of the subject rows in an llvm-cov report."""
    # llvm-cov's row is: filename, then (count, missed, percent) four times over -
    # regions, functions, lines, branches. Thirteen fields, and the filename is
    # unquoted, so a path with spaces would shift the columns. Assert the shape
    # rather than trusting it: a wrong column silently reports a wrong number,
    # which is the exact failure this script is here to prevent.
    counts = {
        "regions": 0, "regions_hit": 0,
        "functions": 0, "functions_hit": 0,
        "lines": 0, "lines_hit": 0,
        "files": 0,
    }
    for line in subject_files(report_text, prefixes):
        parts = line.split()

        # Positional, because the "-" that stands in for "no data" must not be
        # filtered out: dropping it shifts every later column and yields a
        # confidently wrong number rather than an error.
        def count(index: int) -> int:
            try:
                return int(parts[index])
            except (IndexError, ValueError):
                return 0

        counts["regions"] += count(1)
        counts["regions_hit"] += count(1) - count(2)
        counts["functions"] += count(4)
        counts["functions_hit"] += count(4) - count(5)
        counts["lines"] += count(7)
        counts["lines_hit"] += count(7) - count(8)
        counts["files"] += 1
    return counts


def percentages(counts: dict[str, int]) -> dict[str, float]:
    """Turn raw counts into the percentages the floor file records."""
    return {
        "lines": round(100 * counts["lines_hit"] / counts["lines"], 2) if counts["lines"] else 0.0,
        # llvm-cov's Regions column, which for Swift is region coverage. It is
        # NOT branch coverage: Swift emits no branch data, so llvm-cov reports
        # zero for its Branches column and calling that 0% would be a false
        # reading rather than a true one. Named "regions" so nobody can quote it
        # as branch coverage.
        "regions": round(100 * counts["regions_hit"] / counts["regions"], 2)
        if counts["regions"] else 0.0,
        "functions": round(100 * counts["functions_hit"] / counts["functions"], 2)
        if counts["functions"] else 0.0,
        "files": counts["files"],
    }


def combine(all_counts: list[dict[str, int]]) -> dict[str, int]:
    """Sum raw counts across suites."""
    return {key: sum(counts[key] for counts in all_counts) for key in all_counts[0]}


def regressions(
    totals: dict[str, float], suites: dict[str, dict[str, float]], floor: dict
) -> list[str]:
    """Compare the totals and every suite against the recorded floor."""
    found = []
    for metric in ("lines", "regions", "functions"):
        if totals[metric] < floor["totals"][metric] - 0.005:
            found.append(
                f"combined {metric}: {totals[metric]:.2f}% is below the recorded "
                f"floor {floor['totals'][metric]:.2f}%"
            )
    for label, recorded in floor.get("suites", {}).items():
        for metric in ("lines", "regions", "functions"):
            if label not in suites:
                found.append(f"{label}: recorded in the floor but not measured")
                break
            if suites[label][metric] < recorded[metric] - 0.005:
                found.append(
                    f"{label} {metric}: {suites[label][metric]:.2f}% is below the "
                    f"recorded floor {recorded[metric]:.2f}%"
                )
    return found


# The app suite keeps only `NepalKit/`: its harness links `NepalKitCore`, so core
# rows appear in its report too, and counting them would put core's 9 files in
# both suites (app lines 34.79% instead of 30.12% at 0b50f7a).
SUITES = (
    # (label, package path, subject prefixes relative to the repository root)
    ("NepalKitCore", "NepalKitCore", ("NepalKitCore/Sources/NepalKitCore/",)),
    ("NepalKit app", "scripts/apptests", ("NepalKit/",)),
)


def run(command: list[str], cwd: Path | None = None) -> subprocess.CompletedProcess[str]:
    return subprocess.run(command, cwd=cwd, capture_output=True, text=True)


# A persistent build directory per suite, so a second run builds incrementally
# instead of from scratch. Outside the repository on purpose: llvm-cov strips
# the path prefix common to every file it reports, so with the build inside the
# checkout the report's paths lose the repository prefix the subject filter
# matches on. Keyed by checkout so two worktrees do not share builds. Profiles
# from an earlier run are deleted first: the report reads whichever .profdata
# it finds, and a stale one would report the previous run's numbers.
COVERAGE_BUILD = (Path.home() / "Library" / "Caches" / "nepalkit-coverage"
                  / hashlib.sha256(str(REPO_ROOT).encode()).hexdigest()[:12])


def clear_profiles(build_dir: Path) -> int:
    """Delete every .profraw and .profdata under build_dir; return how many."""
    stale = [p for pattern in ("*.profraw", "*.profdata") for p in build_dir.rglob(pattern)]
    for path in stale:
        path.unlink()
    return len(stale)


def measure(
    label: str, package: str, prefixes: tuple[str, ...], build_dir: Path
) -> dict[str, int]:
    """Run one suite with coverage and total its subject files."""
    build_dir.mkdir(parents=True, exist_ok=True)
    # Held until the report is read, so a concurrent run cannot delete this
    # run's profiles between the test and the report.
    with open(build_dir / ".lock", "w") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        return measure_locked(label, package, prefixes, build_dir)


def measure_locked(
    label: str, package: str, prefixes: tuple[str, ...], build_dir: Path
) -> dict[str, int]:
    """measure() with the suite directory's lock held."""
    clear_profiles(build_dir)
    result = run(
        [
            "swift", "test",
            "--package-path", str(REPO_ROOT / package),
            "--enable-code-coverage",
            "--build-path", str(build_dir),
        ]
    )
    if result.returncode != 0:
        print(result.stdout[-2000:], file=sys.stderr)
        raise SystemExit(f"{label}: the suite failed, so its coverage is not measured")

    profiles = list(build_dir.rglob("*.profdata"))
    binaries = [p for p in build_dir.rglob("*.xctest/Contents/MacOS/*") if p.is_file()]
    if not profiles or not binaries:
        raise SystemExit(f"{label}: no coverage data produced; refusing to guess")

    report = run(
        ["xcrun", "llvm-cov", "report", "--instr-profile", str(profiles[0]), str(binaries[0])]
    )
    counts = summarise(report.stdout, prefixes)
    if counts["lines"] == 0:
        raise SystemExit(f"{label}: no subject lines found; the path filter is wrong")
    return counts


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--update", action="store_true", help="record the current numbers as the floor"
    )
    arguments = parser.parse_args()

    raw_counts: dict[str, dict[str, int]] = {}
    raw: dict[str, dict[str, float]] = {}
    for label, package, prefixes in SUITES:
        counts = measure(label, package, prefixes, COVERAGE_BUILD / label.replace(" ", "-"))
        raw_counts[label] = counts
        result = percentages(counts)
        raw[label] = result
        print(f"  {label:<16} lines {result['lines']:6.2f}%  "
              f"regions {result['regions']:6.2f}%  "
              f"functions {result['functions']:6.2f}%  ({result['files']} files)")

    # The combined figure is sum(hit)/sum(lines) across both suites, so a 300-line
    # file weighs 300 lines. A plain mean of the two percentages would let the
    # well-covered calendar engine paper over the app layer.
    totals = percentages(combine(list(raw_counts.values())))

    print(f"  {'combined':<16} lines {totals['lines']:6.2f}%  "
          f"regions {totals['regions']:6.2f}%  "
          f"functions {totals['functions']:6.2f}%  ({totals['files']} files)")

    if arguments.update:
        FLOOR_FILE.write_text(
            json.dumps({"totals": totals, "suites": raw}, indent=2) + "\n", encoding="utf-8"
        )
        print(f"  ok    recorded as the floor in {FLOOR_FILE.relative_to(REPO_ROOT)}")
        return 0

    if not FLOOR_FILE.exists():
        print(f"  FAIL  no floor recorded; run with --update", file=sys.stderr)
        return 1

    floor = json.loads(FLOOR_FILE.read_text(encoding="utf-8"))
    found = regressions(totals, raw, floor)
    if found:
        for regression in found:
            print(f"  FAIL  {regression}", file=sys.stderr)
        print(
            "\n  Coverage fell. Add tests, or accept the lower number deliberately with\n"
            "  --update and say in the commit why a lower number is correct.",
            file=sys.stderr,
        )
        return 1

    print("  ok    no regression against the recorded floor")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
