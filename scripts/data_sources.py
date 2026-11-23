# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Dibas Sigdel
"""The pinned calendar source: fetching, caching and parsing its month table."""

import hashlib
import os
import re
import sys
import urllib.error
import urllib.request
from urllib.parse import urlparse
from pathlib import Path

MONTHS = ["Baisakh", "Jestha", "Ashar", "Shrawan", "Bhadra", "Ashoj",
          "Kartik", "Mangsir", "Poush", "Magh", "Falgun", "Chaitra"]

PINS = {
    "askbuddie": ("https://raw.githubusercontent.com/askbuddie/bikram-sambat/"
                  "d3475606084141352d3bf4472c80f9051968551a/src/data/days-in-month-mapping.ts",
                  "askbuddie/bikram-sambat",
                  "d86f0bcf616579a6c081d8ab61555dbd9cc34d9648cb11799270c35e4ab24782"),
}


class _HTTPSOnlyRedirects(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        if urlparse(newurl).scheme != "https":
            raise urllib.error.URLError("refusing redirect to non-https url %s" % newurl)
        return super().redirect_request(req, fp, code, msg, headers, newurl)


OPENER = urllib.request.build_opener(_HTTPSOnlyRedirects)


def cache_dir():
    root = os.environ.get("NEPAKIT_DATA_CACHE") or str(Path.home() / ".cache" / "nepalkit-data-sources")
    path = Path(root)
    path.mkdir(parents=True, exist_ok=True)
    return path


def _checked(name, raw, digest, where):
    actual = hashlib.sha256(raw).hexdigest()
    if actual != digest:
        sys.exit("the %s table from %s has SHA-256 %s, not the pinned %s" % (name, where, actual, digest))
    return raw.decode("utf-8")


def fetch(name, url, digest, offline):
    cache = cache_dir() / ("%s-%s.ts" % (name, digest[:16]))
    if offline:
        try:
            raw = cache.read_bytes()
        except OSError:
            sys.exit("--offline but no cached copy of the %s table at %s" % (name, cache))
        return _checked(name, raw, digest, cache)
    if urlparse(url).scheme != "https":
        sys.exit("the %s pin is not an https url: %s" % (name, url))
    try:
        with OPENER.open(url, timeout=30) as response:
            raw = response.read()
    except Exception as exc:                      # noqa: BLE001 - report and continue
        print("  could not fetch %s: %s" % (name, exc), file=sys.stderr)
        return None
    body = _checked(name, raw, digest, url)
    cache.write_bytes(raw)
    return body


def check_impossible(rows):
    return ["  note: %d BS sums to %d days, which is impossible; "
            "the source table contains an error" % (year, sum(values))
            for year, values in sorted(rows.items()) if sum(values) not in (365, 366)]


def parse_askbuddie(body):
    pairs = re.findall(r"'(\d{4})'\s*:\s*\[([^\]]+)\]", body)
    return {int(y): [int(x) for x in m.replace(" ", "").split(",")] for y, m in pairs}
