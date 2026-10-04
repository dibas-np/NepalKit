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
statement coverage; this project is at 62.78% combined and the gap is not a
chore. See docs/coverage.md for why the SwiftUI layer is the blocker and what
closing it would actually require. A floor that ratchets upward as tests land
is honest; a target set above the truth is a lie that fails every day.

Offline and credential-free, like every other gate here: coverage needs a
toolchain and nothing else.
"""

from __future__ import annotations

import argparse
import json
import os
import shutil
import subprocess
import sys
import tempfile
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
def subject_files(stdout: str) -> list[str]:
    """Return the report rows whose file is product source, not test source."""
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
        if relative.startswith("NepalKitCore/Sources/NepalKitCore/"):
            keep.append(line)
        elif relative.startswith("NepalKit/"):
            keep.append(line)
    return keep

SUITES = (
    # (label, package path, profdata glob root, binary glob, doc root)
    ("NepalKitCore", "NepalKitCore", "NepalKitCore"),
    ("NepalKit app", "scripts/apptests", "NepalKit"),
)


def run(command: list[str], cwd: Path | None = None) -> subprocess.CompletedProcess[str]:
    return subprocess.run(command, cwd=cwd, capture_output=True, text=True)


def measure(label: str, package: str, build_dir: Path) -> dict[str, float]:
    """Run one suite with coverage and total its subject files."""
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
    # llvm-cov's row is: filename, then (count, missed, percent) four times over -
    # regions, functions, lines, branches. Thirteen fields, and the filename is
    # unquoted, so a path with spaces would shift the columns. Assert the shape
    # rather than trusting it: a wrong column silently reports a wrong number,
    # which is the exact failure this script is here to prevent.
    regions_hit = regions = functions_hit = functions = lines_hit = lines = 0
    files = 0
    for line in subject_files(report.stdout):
        parts = line.split()
        # Positional, because the "-" that stands in for "no data" must not be
        # filtered out: dropping it shifts every later column and yields a
        # confidently wrong number rather than an error.
        def count(index: int) -> int:
            try:
                return int(parts[index])
            except (IndexError, ValueError):
                return 0

        regions += count(1)
        regions_hit += count(1) - count(2)
        functions += count(4)
        functions_hit += count(4) - count(5)
        lines += count(7)
        lines_hit += count(7) - count(8)
        files += 1

    if lines == 0:
        raise SystemExit(f"{label}: no subject lines found; the path filter is wrong")

    return {
        "lines": round(100 * lines_hit / lines, 2),
        # llvm-cov's Regions column, which for Swift is region coverage. It is
        # NOT branch coverage: Swift emits no branch data, so llvm-cov reports
        # zero for its Branches column and calling that 0% would be a false
        # reading rather than a true one. Named "regions" so nobody can quote it
        # as branch coverage.
        "regions": round(100 * regions_hit / regions, 2) if regions else 0.0,
        "functions": round(100 * functions_hit / functions, 2) if functions else 0.0,
        "files": files,
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--update", action="store_true", help="record the current numbers as the floor"
    )
    arguments = parser.parse_args()

    totals = {"lines": 0.0, "regions": 0.0, "functions": 0.0, "files": 0}
    raw: dict[str, dict[str, float]] = {}
    with tempfile.TemporaryDirectory() as directory:
        for label, package, _ in SUITES:
            result = measure(label, package, Path(directory) / label.replace(" ", "-"))
            raw[label] = result
            print(f"  {label:<16} lines {result['lines']:6.2f}%  "
                  f"regions {result['regions']:6.2f}%  "
                  f"functions {result['functions']:6.2f}%  ({result['files']} files)")

    # A plain mean of the two suites would let the well-covered calendar engine
    # paper over the app layer. Weight by file count instead.
    files = sum(r["files"] for r in raw.values())
    for metric in ("lines", "regions", "functions"):
        totals[metric] = round(
            sum(r[metric] * r["files"] for r in raw.values()) / files, 2
        )
    totals["files"] = files

    print(f"  {'combined':<16} lines {totals['lines']:6.2f}%  "
          f"regions {totals['regions']:6.2f}%  "
          f"functions {totals['functions']:6.2f}%  ({files} files)")

    if arguments.update:
        FLOOR_FILE.write_text(
            json.dumps({"totals": totals, "suites": raw}, indent=2) + "\n", encoding="utf-8"
        )
        print(f"  ok    recorded as the floor in {FLOOR_FILE.relative_to(REPO_ROOT)}")
        return 0

    if not FLOOR_FILE.exists():
        print(f"  FAIL  no floor recorded; run with --update", file=sys.stderr)
        return 1

    floor = json.loads(FLOOR_FILE.read_text(encoding="utf-8"))["totals"]
    regressions = [
        f"{metric}: {totals[metric]:.2f}% is below the recorded floor {floor[metric]:.2f}%"
        for metric in ("lines", "regions", "functions")
        if totals[metric] < floor[metric] - 0.005
    ]
    if regressions:
        for regression in regressions:
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
