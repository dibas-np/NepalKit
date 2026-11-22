#!/usr/bin/env python3

# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Dibas Sigdel
"""Usage: python3 scripts/verify-data-sources.py [--offline] [--baseline <path>] [--update-baseline [path]]

--offline reads the pinned source cached in ~/.cache/nepalkit-data-sources/.
--baseline compares with the committed observation and fails on any change.
--update-baseline deliberately regenerates scripts/data-sources-baseline.json
(or the given path); review it together with the source or dataset change.
"""

import json
import sys
from pathlib import Path

from data_sources import MONTHS, NOTES, PINS, fetch, parse_askbuddie
from dataset_table import shipped_table

DATASET = "NepalKitCore/Sources/NepalKitCore/CalendarDataset.swift"

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
