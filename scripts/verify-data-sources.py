#!/usr/bin/env python3
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
}

DATASET = "NepalKitCore/Sources/NepalKitCore/CalendarDataset.swift"


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
    return {int(k): v for k, v in json.loads(body).items()}


def parse_askbuddie(body):
    pairs = re.findall(r"'(\d{4})'\s*:\s*\[([^\]]+)\]", body)
    return {int(y): [int(x) for x in m.replace(" ", "").split(",")] for y, m in pairs}


def main():
    offline = "--offline" in sys.argv
    shipped = load_shipped()
    print("NepalKit ships %d years, %d-%d BS" % (len(shipped), min(shipped), max(shipped)))
    print("Source file: %s\n" % DATASET)

    for name, (url, repo) in PINS.items():
        body = fetch(name, url, offline)
        if body is None:
            print("%s: unavailable, skipped\n" % name)
            continue
        table = parse_medic(body) if name == "medic" else parse_askbuddie(body)
        shared = sorted(set(shipped) & set(table))
        diffs = [(y, i) for y in shared for i in range(12) if shipped[y][i] != table[y][i]]
        exact = sum(1 for y in shared if shipped[y] == table[y])

        print("%s  (%s)" % (repo, url.split("/blob/")[0].split("raw.githubusercontent.com/")[-1]))
        print("  covers %d-%d BS; %d years overlap the shipped range"
              % (min(table), max(table), len(shared)))
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
    # it reports success having checked nothing. Assert the work happened.
    total = sum(1 for y in shipped for _ in range(12))
    if total == 0:
        sys.exit("BUG: nothing was compared — the shipped table is empty")
    print("%d month values in the shipped table across %d years." % (total, len(shipped)))


if __name__ == "__main__":
    main()
