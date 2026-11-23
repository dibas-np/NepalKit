#!/usr/bin/env python3

# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Dibas Sigdel
"""Spot-check the shipped table against the Kathmandu Metropolitan City calendar.

Kept separate from verify-data-sources.py because it reads a live website. KMC
publishes only 2083-2085, so it is used to settle years where the community
tables disagree, not as a source.

Usage:
    scripts/check-kathmandu-calendar.py 2083 2084 2085
    scripts/check-kathmandu-calendar.py --dump 2084     # print the table only

The per-day records are read from the Next.js RSC payload, not the HTML.
"""
import json
import re
import sys
import urllib.error
import urllib.request

from data_sources import MONTHS, OPENER
from dataset_table import shipped_table

BASE = "https://kathmandu.gov.np/en/calendar?view=bs&year={year}&month={month}"
USER_AGENT = "NepalKit-provenance-check/1.0 (calendar data verification)"

RECORD = re.compile(
    r'"bs_year":\s*(\d+),\s*"bs_month":\s*(\d+),\s*"bs_day":\s*(\d+)'
)


def month_lengths(days):
    if set(days) != set(range(1, 13)):
        return None
    return [len(days[m]) for m in range(1, 13)]


def fetch(year, month, timeout=25):
    request = urllib.request.Request(BASE.format(year=year, month=month),
                                     headers={"User-Agent": USER_AGENT})
    with OPENER.open(request, timeout=timeout) as response:
        # The payload is a JSON string inside a JS call, so unescape its quotes.
        return response.read().decode("utf-8", "replace").replace('\\"', '"')


def kmc_year(year):
    days = {}
    for month in range(1, 13):
        try:
            body = fetch(year, month)
        except (urllib.error.URLError, OSError) as exc:
            print("  could not fetch %d-%02d: %s" % (year, month, exc),
                  file=sys.stderr)
            return None
        for record_year, mo, day in RECORD.findall(body):
            # Skip the payload's "today" record, which belongs to another year.
            if int(record_year) != year:
                continue
            days.setdefault(int(mo), set()).add(int(day))
    return month_lengths(days)


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
            print("        not in the shipped table (range is %d-%d)" % (min(shipped), max(shipped)))
            continue
        mine = shipped[year]
        if mine == table:
            print("        matches the shipped table exactly")
        else:
            print("        DIFFERS from the shipped table:")
            for index, (ours, theirs) in enumerate(zip(mine, table)):
                if ours != theirs:
                    print("          %-9s shipped=%d  kmc=%d" % (MONTHS[index], ours, theirs))
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
