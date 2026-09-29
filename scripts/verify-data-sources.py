#!/usr/bin/env python3

# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Dibas Sigdel
"""Re-run NepalKit's shipped calendar table against its two community sources.

The point is reproducibility. The provenance claims in SOURCES.md — that the
shipped table is medic-derived, which months were arbitrated, and in whose favour
— are only worth anything if anyone else can run them and get the same answer.

Read-only. Compares the table in CalendarDataset.swift against each source's
published data and prints every month that differs. It does not judge which side
is correct; that was decided once against published calendars and is recorded in
SOURCES.md, and re-deciding it here would quietly replace a documented decision
with a two-source coin toss.

Usage:  python3 scripts/verify-data-sources.py [--offline]

  --offline   skip the network fetch and only report what is already cached in
              /tmp, for use where the network is unavailable.

Sources are pinned to commits rather than branches: licences get changed
silently, and the base source's own history contains exactly that — a fork that
adopted a licence its upstream never had.
"""

import json
import re
import sys
import urllib.request

MONTHS = ["Baisakh", "Jestha", "Ashar", "Shrawan", "Bhadra", "Ashwin",
          "Kartik", "Mangsir", "Poush", "Magh", "Falgun", "Chaitra"]

# Pinned commits. See SOURCES.md for why each is pinned and what it is for.
PINS = {
    "medic": ("https://raw.githubusercontent.com/medic/bikram-sambat/"
              "aeaa7b88332384bddeea98c2445308d437966641/test-data/daysInMonth.json",
              "medic/bikram-sambat"),
    "askbuddie": ("https://raw.githubusercontent.com/askbuddie/bikram-sambat/"
                  "d3475606084141352d3bf4472c80f9051968551a/src/data/days-in-month-mapping.ts",
                  "askbuddie/bikram-sambat"),
    "go-bs": ("https://raw.githubusercontent.com/SuprimKhatri77/go-bs/"
              "5853e0e91482d8bb6f400da4f69138fbe69a85dc/data.go",
              "SuprimKhatri77/go-bs"),
    "nepali-date": ("https://raw.githubusercontent.com/subeshb1/Nepali-Date/"
                    "2183c30ada24a7fe678a24d58a5aa61ce8cdfa85/src/date-config.ts",
                    "subeshb1/Nepali-Date"),
}

DATASET = "NepalKitCore/Sources/NepalKitCore/CalendarDataset.swift"

# Diagnostics raised while parsing, flushed after the source's heading. A parse
# runs before its source is named, so printing immediately attributes its
# warnings to whichever source was reported last.
NOTES = []


def load_shipped():
    """Parse the shipped table straight out of the source file."""
    text = open(DATASET, encoding="utf-8").read()
    rows = re.findall(r"^            (\d{4}): \[([\d,\s]+)\],", text, re.M)
    if not rows:
        sys.exit("no rows parsed from %s — the format changed?" % DATASET)
    return {int(y): [int(x) for x in m.split(",")] for y, m in rows}


def fetch(name, url, offline):
    cache = "/tmp/%s-days.json" % name
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


def parse_medic(body):
    rows = {int(k): v for k, v in json.loads(body).items()}
    check_impossible(rows)
    return rows


def check_impossible(rows):
    """Flag year totals that cannot occur. Applies to every source, not one."""
    for year, values in sorted(rows.items()):
        if sum(values) not in (365, 366):
            NOTES.append("  note: %d BS sums to %d days, which is impossible; "
                         "the source table contains an error" % (year, sum(values)))


def parse_go_bs(body):
    """Parse go-bs's generated Go table: rows are positional, with the year in a comment.

    The array is indexed from MinBSYear rather than keyed by year, so the year has
    to come from the trailing comment. Guessing the range instead would silently
    shift every row if MinBSYear ever moves.
    """
    rows = {}
    for lengths, year in re.findall(r"\{([\d,\s]+)\},\s*//\s*(\d{4})", body):
        rows[int(year)] = [int(x) for x in lengths.split(",") if x.strip()]
    if not rows:
        return {}
    # A year table is 365 or 366 days. Anything else means the parse went wrong,
    # and a silently mis-parsed comparison is worse than no comparison.
    check_impossible(rows)
    return rows


def parse_nepali_date(body):
    """Parse subeshb1/Nepali-Date's date-config map.

    Keyed by month *name* rather than index, so the order is taken from the type
    declaration at the top of the file instead of being assumed. A source that
    reordered its months would otherwise be compared month-for-month against the
    wrong column and produce a table of plausible-looking nonsense.
    """
    order = re.search(r"\[year: string\]: \{(.*?)\n\}", body, re.S)
    if not order:
        return {}
    months = re.findall(r"([A-Za-z]+):\s*number", order.group(1))
    table = {}
    for year, block in re.findall(r"'(\d{4})'\s*:\s*\{(.*?)\n  \}", body, re.S):
        values = []
        for month in months:
            found = re.search(month + r":\s*(\d+)", block)
            if not found:
                values = None
                break
            values.append(int(found.group(1)))
        if values:
            table[int(year)] = values
    return table


def parse_askbuddie(body):
    pairs = re.findall(r"'(\d{4})'\s*:\s*\[([^\]]+)\]", body)
    return {int(y): [int(x) for x in m.replace(" ", "").split(",")] for y, m in pairs}


def main():
    offline = "--offline" in sys.argv
    shipped = load_shipped()
    compared = 0
    print("NepalKit ships %d years, %d-%d BS" % (len(shipped), min(shipped), max(shipped)))
    print("Source file: %s\n" % DATASET)

    for name, (url, repo) in PINS.items():
        body = fetch(name, url, offline)
        if body is None:
            print("%s: unavailable, skipped\n" % name)
            continue
        del NOTES[:]
        table = {"medic": parse_medic, "askbuddie": parse_askbuddie,
                 "go-bs": parse_go_bs, "nepali-date": parse_nepali_date}[name](body)
        shared = sorted(set(shipped) & set(table))
        compared += len(shared)
        diffs = [(y, i) for y in shared for i in range(12) if shipped[y][i] != table[y][i]]
        exact = sum(1 for y in shared if shipped[y] == table[y])

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


if __name__ == "__main__":
    main()
