#!/usr/bin/env python3

# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Dibas Sigdel
"""Compare NepalKit's dataset with its sole pinned base, askbuddie.

All differences are explicit NepalKit corrections or the local 2084 projection.
A passing baseline check establishes that the recorded comparison still holds,
not that either table is officially attested. See SOURCES.md.

Usage: python3 scripts/verify-data-sources.py [--offline] [--baseline <path>] [--update-baseline [path]]

--offline reads the pinned source cached in ~/.cache/nepalkit-data-sources/.
--baseline compares with the committed observation and fails on any change.
--update-baseline deliberately regenerates scripts/data-sources-baseline.json
(or the given path); review it together with the source or dataset change.
"""

import json
import os
import re
import sys
import urllib.request
from pathlib import Path

from dataset_table import shipped_table

MONTHS = ["Baisakh", "Jestha", "Ashar", "Shrawan", "Bhadra", "Ashwin",
          "Kartik", "Mangsir", "Poush", "Magh", "Falgun", "Chaitra"]

# Pinned commits. See SOURCES.md for why each is pinned and what it is for.
PINS = {
    "askbuddie": ("https://raw.githubusercontent.com/askbuddie/bikram-sambat/"
                  "d3475606084141352d3bf4472c80f9051968551a/src/data/days-in-month-mapping.ts",
                  "askbuddie/bikram-sambat"),
}

DATASET = "NepalKitCore/Sources/NepalKitCore/CalendarDataset.swift"

# Diagnostics raised while parsing, flushed after the source's heading. A parse
# runs before its source is named, so printing immediately attributes its
# warnings to whichever source was reported last.
NOTES = []


def cache_dir():
    """Where fetched source tables are cached between runs.

    A per-user directory, not /tmp: --offline reads whatever is cached there,
    and a fixed world-writable path would let planted bytes flow into a
    comparison this project treats as provenance evidence. Override with
    NEPAKIT_DATA_CACHE for tests or read-only environments.
    """
    root = os.environ.get("NEPAKIT_DATA_CACHE") or str(Path.home() / ".cache" / "nepalkit-data-sources")
    path = Path(root)
    path.mkdir(parents=True, exist_ok=True)
    return path


def fetch(name, url, offline):
    cache = str(cache_dir() / ("%s-days.json" % name))
    if offline:
        try:
            return open(cache, encoding="utf-8").read()
        except OSError:
            sys.exit("--offline but no cached copy of the %s table at %s" % (name, cache))
    try:
        with urllib.request.urlopen(url, timeout=30) as response:
            body = response.read().decode("utf-8")
    except Exception as exc:                      # noqa: BLE001 - report and continue
        print("  could not fetch %s: %s" % (name, exc), file=sys.stderr)
        return None
    open(cache, "w", encoding="utf-8").write(body)
    return body


def check_impossible(rows):
    """Flag year totals that cannot occur. Applies to every source, not one."""
    for year, values in sorted(rows.items()):
        if sum(values) not in (365, 366):
            NOTES.append("  note: %d BS sums to %d days, which is impossible; "
                         "the source table contains an error" % (year, sum(values)))


def parse_askbuddie(body):
    pairs = re.findall(r"'(\d{4})'\s*:\s*\[([^\]]+)\]", body)
    return {int(y): [int(x) for x in m.replace(" ", "").split(",")] for y, m in pairs}


DEFAULT_BASELINE = Path("scripts/data-sources-baseline.json")


def _parse_argv(argv):
    offline = "--offline" in argv
    baseline = None
    update = None
    i = 0
    args = list(argv)
    while i < len(args):
        arg = args[i]
        if arg == "--baseline":
            if i + 1 >= len(args) or args[i + 1].startswith("--"):
                sys.exit("--baseline needs a path: --baseline scripts/data-sources-baseline.json")
            baseline = Path(args[i + 1])
            i += 2
            continue
        if arg.startswith("--baseline="):
            baseline = Path(arg.split("=", 1)[1])
            i += 1
            continue
        if arg == "--update-baseline":
            if i + 1 < len(args) and not args[i + 1].startswith("--"):
                update = Path(args[i + 1])
                i += 2
            else:
                update = DEFAULT_BASELINE
                i += 1
            continue
        if arg.startswith("--update-baseline="):
            update = Path(arg.split("=", 1)[1])
            i += 1
            continue
        i += 1
    return offline, baseline, update


def _describe_month(year, index):
    return "%d %s [%d, %d]" % (year, MONTHS[index], year, index)


def _compare_observations(observed, expected):
    problems = []
    exp_shipped = expected.get("shipped", {})
    obs_shipped = observed.get("shipped", {})
    if obs_shipped != exp_shipped:
        problems.append("shipped range changed: baseline %s, live %s"
                        % (exp_shipped, obs_shipped))
    exp_sources = expected.get("sources", {})
    obs_sources = observed.get("sources", {})
    for name in sorted(set(exp_sources) | set(obs_sources)):
        if name not in obs_sources:
            problems.append("%s: missing from live observation" % name)
            continue
        if name not in exp_sources:
            problems.append("%s: new source not in baseline "
                            "(shared=%d, exact=%d)"
                            % (name, obs_sources[name]["shared"],
                               obs_sources[name]["exact"]))
            continue
        exp = exp_sources[name]
        obs = obs_sources[name]
        if obs["shared"] != exp["shared"]:
            problems.append("%s: shared years changed: baseline %d, live %d"
                            % (name, exp["shared"], obs["shared"]))
        if obs["exact"] != exp["exact"]:
            problems.append("%s: exact years changed: baseline %d, live %d"
                            % (name, exp["exact"], obs["exact"]))
        exp_diffs = {tuple(d) for d in exp["diffs"]}
        obs_diffs = {tuple(d) for d in obs["diffs"]}
        for y, m in sorted(obs_diffs - exp_diffs):
            problems.append("%s: new differing month %s not in baseline"
                            % (name, _describe_month(y, m)))
        for y, m in sorted(exp_diffs - obs_diffs):
            problems.append("%s: vanished differing month %s "
                            "recorded in baseline but not observed"
                            % (name, _describe_month(y, m)))
        exp_uncovered = set(exp["uncovered"])
        obs_uncovered = set(obs["uncovered"])
        for y in sorted(obs_uncovered - exp_uncovered):
            problems.append("%s: newly uncovered year %d "
                            "not in baseline" % (name, y))
        for y in sorted(exp_uncovered - obs_uncovered):
            problems.append("%s: vanished uncovered year %d "
                            "recorded in baseline but now covered" % (name, y))
    return problems


def main():
    offline, baseline_path, update_path = _parse_argv(sys.argv[1:])
    shipped = shipped_table()
    compared = 0
    print("NepalKit ships %d years, %d-%d BS" % (len(shipped), min(shipped), max(shipped)))
    print("Source file: %s\n" % DATASET)

    observation = {
        "shipped": {"years": len(shipped), "first": min(shipped), "last": max(shipped)},
        "sources": {},
    }

    for name, (url, repo) in PINS.items():
        body = fetch(name, url, offline)
        if body is None:
            print("%s: unavailable, skipped\n" % name)
            observation["sources"][name] = {
                "shared": 0,
                "exact": 0,
                "diffs": [],
                "uncovered": sorted(shipped),
            }
            continue
        del NOTES[:]
        table = parse_askbuddie(body)
        if not table:
            print("%s  (%s)" % (repo, url.split("/blob/")[0].split("raw.githubusercontent.com/")[-1]))
            print("  no rows parsed; 0 years overlap the shipped range\n")
            observation["sources"][name] = {
                "shared": 0,
                "exact": 0,
                "diffs": [],
                "uncovered": sorted(shipped),
            }
            continue
        shared = sorted(set(shipped) & set(table))
        compared += len(shared)
        diffs = [(y, i) for y in shared for i in range(12) if shipped[y][i] != table[y][i]]
        exact = sum(1 for y in shared if shipped[y] == table[y])

        observation["sources"][name] = {
            "shared": len(shared),
            "exact": exact,
            "diffs": [[y, i] for y, i in diffs],
            "uncovered": sorted(set(shipped) - set(table)),
        }

        print("%s  (%s)" % (repo, url.split("/blob/")[0].split("raw.githubusercontent.com/")[-1]))
        for note in NOTES:
            print(note)
        print("  covers %d-%d BS; %d years overlap the shipped range"
              % (min(table), max(table), len(shared)))
        uncovered = sorted(set(shipped) - set(table))
        if uncovered:
            print("  CANNOT COVER %d shipped year(s): %s"
                  % (len(uncovered), ", ".join(str(y) for y in uncovered)))
        print("  %d of %d years match exactly" % (exact, len(shared)))
        print("  months compared: %d" % (len(shared) * 12))
        if diffs:
            print("  %d differing month(s):" % len(diffs))
            for y, i in diffs:
                print("    %d %-9s shipped=%-3d source=%-3d"
                      % (y, MONTHS[i], shipped[y][i], table[y][i]))
        else:
            print("  no differing months")
        print()

    # A comparison that silently compares nothing is worse than no comparison:
    # it reports success having checked nothing. Every fetch can fail, so a
    # green exit must mean at least one source actually overlapped the table.
    if compared == 0:
        sys.exit("nothing was compared — no source was reachable or none overlap the shipped range")
    print("%d month values in the shipped table across %d years; %d year(s) were checked."
          % (len(shipped) * 12, len(shipped), compared))

    if update_path is not None:
        update_path.parent.mkdir(parents=True, exist_ok=True)
        update_path.write_text(json.dumps(observation, indent=2, sort_keys=True) + "\n",
                               encoding="utf-8")
        print(json.dumps(observation, indent=2, sort_keys=True))
        return

    if baseline_path is not None:
        try:
            expected = json.loads(baseline_path.read_text(encoding="utf-8"))
        except OSError:
            sys.exit("no baseline at %s — generate it: "
                     "python3 scripts/verify-data-sources.py --update-baseline"
                     % baseline_path)
        problems = _compare_observations(observation, expected)
        if problems:
            print("baseline mismatch against %s:" % baseline_path)
            for problem in problems:
                print("  " + problem)
            sys.exit(1)
        total_diffs = sum(len(entry["diffs"]) for entry in observation["sources"].values())
        print("baseline holds: %d sources, %d source/month comparison pairs "
              "(all recorded in baseline)"
              % (len(observation["sources"]), total_diffs))


if __name__ == "__main__":
    main()
