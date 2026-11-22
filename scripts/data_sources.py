# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Dibas Sigdel
"""The pinned calendar source: fetching, caching and parsing its month table."""

import os
import re
import sys
import urllib.request
from pathlib import Path

MONTHS = ["Baisakh", "Jestha", "Ashar", "Shrawan", "Bhadra", "Ashoj",
          "Kartik", "Mangsir", "Poush", "Magh", "Falgun", "Chaitra"]

PINS = {
    "askbuddie": ("https://raw.githubusercontent.com/askbuddie/bikram-sambat/"
                  "d3475606084141352d3bf4472c80f9051968551a/src/data/days-in-month-mapping.ts",
                  "askbuddie/bikram-sambat"),
}

def cache_dir():
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
    return ["  note: %d BS sums to %d days, which is impossible; "
            "the source table contains an error" % (year, sum(values))
            for year, values in sorted(rows.items()) if sum(values) not in (365, 366)]


def parse_askbuddie(body):
    pairs = re.findall(r"'(\d{4})'\s*:\s*\[([^\]]+)\]", body)
    return {int(y): [int(x) for x in m.replace(" ", "").split(",")] for y, m in pairs}
