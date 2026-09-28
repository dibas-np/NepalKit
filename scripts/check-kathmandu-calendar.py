#!/usr/bin/env python3

# SPDX-License-Identifier: GPL-3.0-or-later
"""Spot-check the shipped table against the Kathmandu Metropolitan City calendar.

Why this is separate from verify-data-sources.py: that script compares pinned,
immutable files, so its results never change. This one reads a **live government
website**, so its results can change under us, the site can go down, and each year
costs twelve requests. Keeping it apart means the reproducible comparison stays
reproducible, and a live check is something you run deliberately.

It is a *spot-check*, not a source. KMC publishes only 2083-2085, so it cannot
cover the shipped range and can never be the base table. What it is good for is
adjudicating the years where the community tables disagree.

Usage:
    scripts/check-kathmandu-calendar.py 2083 2084 2085
    scripts/check-kathmandu-calendar.py --dump 2084     # print the table only

The site renders its calendar into a Next.js RSC payload rather than server-side
HTML, so the per-day records are extracted from the escaped JSON in that payload
rather than from the markup. The record shape is ``bs_year``/``bs_month``/
``bs_day`` with an ``ad_date`` beside it; only the BS triple is needed here.
"""
import json
import pathlib
import re
import sys
import urllib.error
import urllib.request

DATASET = "NepalKitCore/Sources/NepalKitCore/CalendarDataset.swift"
BASE = "https://kathmandu.gov.np/en/calendar?view=bs&year={year}&month={month}"
USER_AGENT = "NepalKit-provenance-check/1.0 (calendar data verification)"

RECORD = re.compile(
    r'"bs_year":\s*(\d+),\s*"bs_month":\s*(\d+),\s*"bs_day":\s*(\d+)'
)


def shipped_table():
    text = pathlib.Path(DATASET).read_text(encoding="utf-8")
    block = text[text.index("years: ["):]
    block = block[:block.index("\n        ],")]
    return {int(m.group(1)): [int(x) for x in m.group(2).split(",") if x.strip()]
            for m in re.finditer(r"(\d{4}):\s*\[([\d,\s]+)\]", block)}


def fetch(year, month, timeout=25):
    request = urllib.request.Request(BASE.format(year=year, month=month),
                                     headers={"User-Agent": USER_AGENT})
    with urllib.request.urlopen(request, timeout=timeout) as response:
        # The payload is a JSON string embedded in a JS call, so its quotes are
        # backslash-escaped. Unescaping first means the record pattern below can
        # be written against plain JSON rather than against escaping rules.
        return response.read().decode("utf-8", "replace").replace('\\"', '"')


def kmc_year(year):
    """Month lengths for one BS year, or None if the site has no data for it."""
    days = {}
    for month in range(1, 13):
        try:
            body = fetch(year, month)
        except (urllib.error.URLError, OSError) as exc:
            print("  could not fetch %d-%02d: %s" % (year, month, exc),
                  file=sys.stderr)
            return None
        for _, mo, day in RECORD.findall(body):
            days.setdefault(int(mo), set()).add(int(day))
    if len(days) != 12:
        return None
    # Count distinct days rather than trusting the row count: a truncated or
    # partially-rendered month would otherwise look like a short month and be
    # reported as a real disagreement.
    return [len(days[m]) for m in range(1, 13)]


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("-")]
    dump_only = "--dump" in sys.argv
    if not args:
        sys.exit(__doc__)
    shipped = shipped_table()

    for year in (int(a) for a in args):
        table = kmc_year(year)
        if table is None:
            print("%d BS: no data on the site (it publishes 2083-2085 only)" % year)
            continue
        if dump_only:
            print("%d: %s  (%d days)" % (year, table, sum(table)))
            continue
        total = sum(table)
        note = "" if total in (365, 366) else "  <-- IMPOSSIBLE YEAR LENGTH"
        print("%d BS: %s  (%d days)%s" % (year, table, total, note))
        if year not in shipped:
            print("        not in the shipped table (range is 1975-2084)")
            continue
        mine = shipped[year]
        if mine == table:
            print("        matches the shipped table exactly")
        else:
            months = ["Baisakh", "Jestha", "Ashadh", "Shrawan", "Bhadra", "Ashwin",
                      "Kartik", "Mangsir", "Poush", "Magh", "Falgun", "Chaitra"]
            print("        DIFFERS from the shipped table:")
            for index, (ours, theirs) in enumerate(zip(mine, table)):
                if ours != theirs:
                    print("          %-9s shipped=%d  kmc=%d" % (months[index], ours, theirs))
            print("        year totals: shipped=%d kmc=%d%s"
                  % (sum(mine), total,
                     "  <-- a different year length, not a transposition"
                     if sum(mine) != total else ""))
    print("\nNote: a match is corroboration of the values, not proof of official "
          "attestation.\nKMC republishes the national calendar, but showing a "
          "future BS year is also\nwhat a projection does. Only the Panchanga "
          "Nirnayak Samiti can attest a year.")


if __name__ == "__main__":
    main()
