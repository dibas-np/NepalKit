#!/usr/bin/env python3

# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Dibas Sigdel
"""Report the sole pinned base source's row for a candidate Bikram Sambat year.

Usage: python3 scripts/verify-candidate-year.py 2085 [month_lengths_csv]

Pins, caching and parsing are shared with verify-data-sources.py. Differences
are reported rather than resolved. A row in a community table is not proof of
an official calendar publication. Only 2084 has an explicitly approved local
projection; a later year needs evidence under ADR-0014 before adoption.
"""

from __future__ import annotations

import importlib.util
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
# verify-data-sources.py does `from dataset_table import shipped_table` at import
# time, so scripts/ must be importable however this file was invoked. Loading it
# by path mirrors how test_dataset_parsers.py loads it, rather than importing a
# name that is not a valid module identifier.
if str(HERE) not in sys.path:
    sys.path.insert(0, str(HERE))


def load(name):
    spec = importlib.util.spec_from_file_location(name.replace("-", "_"), HERE / name)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


vds = load("verify-data-sources.py")


MONTHS = vds.MONTHS


def parse_candidate(text, year):
    """The candidate row as twelve month lengths, or exit with the reason why."""
    parts = [p for p in text.replace(" ", "").split(",") if p]
    if len(parts) != 12:
        sys.exit("a candidate year has 12 months; got %d from %r"
                 % (len(parts), text))
    try:
        return [int(p) for p in parts]
    except ValueError:
        sys.exit("candidate month lengths must be whole numbers: %r" % text)


def fetch_row(name, year):
    """One source's row for `year`, or None if it publishes no such year.

    Raises on a fetch failure: an unreadable source is this script's problem to
    report as a failure, distinct from a source that simply has nothing to say.
    """
    url, repo = vds.PINS[name]
    body = vds.fetch(name, url, False)
    if body is None:
        raise OSError("could not fetch %s (%s)" % (name, url))
    del vds.NOTES[:]
    table = vds.parse_askbuddie(body)
    if not table:
        raise ValueError("%s fetched, but no rows parsed — the file's shape "
                         "changed and the comparison would be silently empty"
                         % name)
    return repo, table.get(year), list(vds.NOTES), min(table), max(table)


def main():
    args = sys.argv[1:]
    if any(a in ("-h", "--help") for a in args) or not args:
        sys.exit(__doc__)

    try:
        year = int(args[0])
    except ValueError:
        sys.exit("the year must be a whole BS year, e.g. 2085; got %r" % args[0])
    candidate = parse_candidate(args[1], year) if len(args) > 1 else None

    print("What the pinned sources publish for %d BS\n" % year)
    if candidate is None:
        print("No candidate row given, so there is nothing to compare against. "
              "Pass one\nas a comma-separated list of twelve month lengths to "
              "get the agreement\ntable.\n")

    rows = {}
    failed = []
    for name in vds.PINS:
        try:
            repo, row, notes, first, last = fetch_row(name, year)
        except (OSError, ValueError) as exc:
            print("%-13s ERROR  %s" % (name, exc))
            failed.append(name)
            continue
        rows[name] = row
        print("%-13s %s" % (name, repo))
        if row is None:
            # Named explicitly. A source that publishes no row for the year is
            # not a source that agrees with the others.
            print("  no row for %d BS (this table covers %d-%d BS)"
                  % (year, first, last))
            print()
            continue
        print("  %s  (%d days)" % (row, sum(row)))
        # Notes the parser raised about the whole table, not this year: a source
        # that flags its own impossible year is telling you how far to trust it.
        for note in notes:
            print("  elsewhere in this table — %s" % note.strip())
        del vds.NOTES[:]
        vds.check_impossible({year: row})
        for note in vds.NOTES:
            print(note)

    published = {name: row for name, row in rows.items() if row is not None}
    if failed:
        print("\n%d of %d sources could not be read (%s). Treat this run as "
              "incomplete:\na comparison that silently skips a source reports "
              "agreement it did not earn."
              % (len(failed), len(vds.PINS), ", ".join(failed)))
        return 1
    if not published:
        print("\nNo pinned source publishes a row for %d BS. That is an answer, "
              "not a\npass: there is nothing here to corroborate against."
              % year)
        return 0

    if candidate is None:
        print("%d of %d pinned sources publish %d BS: %s"
              % (len(published), len(vds.PINS), year,
                 ", ".join(sorted(published))))
        return 0

    print("\nCandidate %d BS: %s  (%d days)" % (year, candidate, sum(candidate)))
    # Classify whole rows, not months. A source that agrees on eleven months and
    # is wrong on the twelfth has not agreed, and counting it as agreement would
    # report a year with a different total as corroborated.
    differing = {name: [i for i in range(12) if row[i] != candidate[i]]
                 for name, row in published.items()}
    differing = {name: idxs for name, idxs in differing.items() if idxs}
    agreeing = [name for name in published if name not in differing]

    print("%-9s %-7s %s" % ("month", "value", "  ".join("%-11s" % name
                                                        for name in published)))
    for index, month in enumerate(MONTHS):
        cells = ["%-11s" % ("%d  ==" % published[name][index]
                            if index not in differing.get(name, ())
                            else "%d  !=" % published[name][index])
                 for name in published]
        print("%-9s %-7d %s" % (month, candidate[index], "  ".join(cells)))

    for name in sorted(differing):
        row = published[name]
        months = ["%s(%d!=%d)" % (MONTHS[i], candidate[i], row[i])
                  for i in differing[name]]
        print("\n%s differs from the candidate in %d month(s):\n  %s"
              % (name, len(months), ", ".join(months)))
        print("  year totals: candidate=%d %s=%d%s"
              % (sum(candidate), name, sum(row),
                 "  <-- a different year length, not a transposition"
                 if sum(row) != sum(candidate) else ""))

    print("\n%d of %d published sources agree; disagreements: %s"
          % (len(agreeing), len(published),
             ", ".join(sorted(differing)) if differing else "none"))
    if differing:
        print("A disagreement is a report, not a failure. SOURCES.md records the "
              "shipped\ntable's corrections and projection; add this one "
              "there rather than\nresolving it here.")

    del vds.NOTES[:]
    vds.check_impossible({year: candidate})
    print("\nCandidate year total: %d day(s)%s"
          % (sum(candidate),
             " — POSSIBLE" if sum(candidate) in (365, 366) else ""))
    for note in vds.NOTES:
        print(note)
    if vds.NOTES:
        print("The candidate cannot be transcribed as it stands: a BS year is "
              "365 or 366\ndays. Re-read the row before shipping it.")
    print("\nAttestation is not what this script measures. Agreement between "
          "projections is\nnot attestation: only the Samiti's published almanac "
          "attests a year. See ADR-0014 and SOURCES.md.")


if __name__ == "__main__":
    sys.exit(main())
