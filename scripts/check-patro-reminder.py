#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Dibas Sigdel
"""Fail when the monthly Nepali Patro check is overdue.

The shipped table ends at 2084 BS (2028-04-12), and 2084 is a projection. The
Samiti's determination of 2084 is expected around Magh 2083 BS (January to
February 2027), and only its published almanac makes a year attested or a new
year shippable (ADR-0014). Nothing machine-readable announces it, so this does
not look for the publication. It checks that a person has: the
`last_checked:` line in docs/release-evidence/dataset-extension-procedure.md
must be no older than 35 days.

Quiet before 2027-01-01, when the monthly check starts, and quiet once the
shipped table reaches 2085, when the extension has shipped.

    scripts/check-patro-reminder.py [--today YYYY-MM-DD]
"""

from __future__ import annotations

import argparse
import datetime
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
PROCEDURE = ROOT / "docs" / "release-evidence" / "dataset-extension-procedure.md"
CHECKS_START = datetime.date(2027, 1, 1)
MAX_AGE_DAYS = 35
EXTENDED_YEAR = 2085


def last_checked(procedure_text: str) -> datetime.date | None:
    """The recorded check date, or None for `none`. Exits if the line is missing or malformed."""
    match = re.search(r"^last_checked:\s*(\S+)\s*$", procedure_text, re.M)
    if not match:
        sys.exit(f"no `last_checked:` line in {PROCEDURE}")
    value = match.group(1)
    if value == "none":
        return None
    try:
        return datetime.date.fromisoformat(value)
    except ValueError:
        sys.exit(f"`last_checked: {value}` is not a YYYY-MM-DD date")


def verdict(today: datetime.date, checked: datetime.date | None, last_year: int) -> tuple[bool, str]:
    """(ok, message) for the reminder."""
    if last_year >= EXTENDED_YEAR:
        return True, f"the shipped table reaches {last_year} BS; the reminder is done"
    if today < CHECKS_START:
        return True, f"the monthly Patro check starts {CHECKS_START}; nothing is due yet"
    if checked is None:
        return False, ("the monthly Patro check has never been recorded. Read the Samiti's "
                       "notices on npns.gov.np, then set `last_checked:` in "
                       "docs/release-evidence/dataset-extension-procedure.md")
    age = (today - checked).days
    if age < -1:
        # A future date would make the age negative and pass forever. One day of
        # slack covers a local date ahead of the runner's UTC date.
        return False, (f"`last_checked: {checked}` is in the future; record the date the "
                       "check was actually made")
    if age > MAX_AGE_DAYS:
        return False, (f"the monthly Patro check is overdue: last recorded {checked}, {age} days ago. "
                       "Read the Samiti's notices on npns.gov.np, follow the procedure, and update "
                       "`last_checked:`. Matching community tables are not attestation.")
    return True, f"Patro check recorded {checked}, {age} days ago"


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    parser.add_argument("--today", type=datetime.date.fromisoformat, default=datetime.date.today())
    args = parser.parse_args(argv)

    sys.path.insert(0, str(ROOT / "scripts"))
    from dataset_table import shipped_table

    last_year = max(shipped_table())
    # The record is read only when a check is due: before 2027 and after 2085
    # ships the job stays quiet even if the line is gone. The pull-request suite
    # still requires the committed line to be readable.
    quiet = args.today < CHECKS_START or last_year >= EXTENDED_YEAR
    checked = None if quiet else last_checked(PROCEDURE.read_text(encoding="utf-8"))
    ok, message = verdict(args.today, checked, last_year)
    print(("  ok    " if ok else "  FAIL  ") + message)
    return 0 if ok else 1


if __name__ == "__main__":
    raise SystemExit(main())
