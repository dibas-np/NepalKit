#!/usr/bin/env python3
"""Measure Swift coverage for NepalKitCore and the app suite (scripts/apptests).

    scripts/measure-coverage.py            # measure, compare to the floor, report
    scripts/measure-coverage.py --update   # accept the current numbers as the floor

Fails if coverage drops below scripts/coverage-floor.json.
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

def subject_files(stdout: str, prefixes: tuple[str, ...]) -> list[str]:
    keep = []
    # llvm-cov strips the directory prefix common to every file, which may be
    # part of the repository path, so try every tail of the root, longest first.
    full = str(REPO_ROOT).lstrip("/") + "/"
    tails = [full] + [full[i + 1:] for i, c in enumerate(full[:-1]) if c == "/"]
    for line in stdout.splitlines():
        parts = line.split()
        if len(parts) != 13:
            continue
        root = next((tail for tail in tails if parts[0].startswith(tail)), None)
        if root is None:
            continue
        relative = parts[0][len(root):]
        if any(relative.startswith(prefix) for prefix in prefixes):
            keep.append(line)
    return keep


def summarise(report_text: str, prefixes: tuple[str, ...]) -> dict[str, int]:
    # Filename then (count, missed, percent) for regions, functions, lines and
    # branches.
    counts = {
        "regions": 0, "regions_hit": 0,
        "functions": 0, "functions_hit": 0,
        "lines": 0, "lines_hit": 0,
        "files": 0,
    }
    for line in subject_files(report_text, prefixes):
        parts = line.split()

        # Positional, so a "-" (no data) does not shift later columns.
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
    return {
        "lines": round(100 * counts["lines_hit"] / counts["lines"], 2) if counts["lines"] else 0.0,
        # Swift emits no branch data, so llvm-cov's Branches is always 0.
        "regions": round(100 * counts["regions_hit"] / counts["regions"], 2)
        if counts["regions"] else 0.0,
        "functions": round(100 * counts["functions_hit"] / counts["functions"], 2)
        if counts["functions"] else 0.0,
        "files": counts["files"],
    }


def combine(all_counts: list[dict[str, int]]) -> dict[str, int]:
    return {key: sum(counts[key] for counts in all_counts) for key in all_counts[0]}


def regressions(
    totals: dict[str, float], suites: dict[str, dict[str, float]], floor: dict
) -> list[str]:
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


SUITES = (
    ("NepalKitCore", "NepalKitCore", ("NepalKitCore/Sources/NepalKitCore/",)),
    ("NepalKit app", "scripts/apptests", ("NepalKit/",)),
)


def run(command: list[str], cwd: Path | None = None) -> subprocess.CompletedProcess[str]:
    return subprocess.run(command, cwd=cwd, capture_output=True, text=True)


# Persistent per-checkout build directories outside the repository (llvm-cov's
# prefix stripping would otherwise break the path filter).
COVERAGE_BUILD = (Path.home() / "Library" / "Caches" / "nepalkit-coverage"
                  / hashlib.sha256(str(REPO_ROOT).encode()).hexdigest()[:12])


def clear_profiles(build_dir: Path) -> int:
    stale = [p for pattern in ("*.profraw", "*.profdata") for p in build_dir.rglob(pattern)]
    for path in stale:
        path.unlink()
    return len(stale)


def measure(
    label: str, package: str, prefixes: tuple[str, ...], build_dir: Path
) -> dict[str, int]:
    build_dir.mkdir(parents=True, exist_ok=True)
    with open(build_dir / ".lock", "w") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        return measure_locked(label, package, prefixes, build_dir)


def measure_locked(
    label: str, package: str, prefixes: tuple[str, ...], build_dir: Path
) -> dict[str, int]:
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
