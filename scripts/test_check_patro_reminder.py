#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Dibas Sigdel
"""Suite for check-patro-reminder.py: when the monthly Patro check is due."""

from __future__ import annotations

import datetime
import importlib.util
import unittest
from pathlib import Path

_SCRIPT = Path(__file__).resolve().parent / "check-patro-reminder.py"
_spec = importlib.util.spec_from_file_location("check_patro_reminder", _SCRIPT)
cpr = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(cpr)

D = datetime.date


class Verdict(unittest.TestCase):
    def test_quiet_before_the_checks_start(self):
        ok, _ = cpr.verdict(D(2026, 12, 31), None, 2084)
        self.assertTrue(ok)

    def test_never_recorded_fails_once_checks_start(self):
        ok, message = cpr.verdict(D(2027, 1, 1), None, 2084)
        self.assertFalse(ok)
        self.assertIn("never been recorded", message)

    def test_recent_check_passes(self):
        ok, _ = cpr.verdict(D(2027, 2, 10), D(2027, 1, 10), 2084)
        self.assertTrue(ok)

    def test_thirty_five_days_is_still_on_time(self):
        ok, _ = cpr.verdict(D(2027, 2, 14), D(2027, 1, 10), 2084)
        self.assertTrue(ok)

    def test_older_than_thirty_five_days_fails(self):
        ok, message = cpr.verdict(D(2027, 2, 15), D(2027, 1, 10), 2084)
        self.assertFalse(ok)
        self.assertIn("overdue", message)

    def test_silent_once_2085_ships(self):
        ok, message = cpr.verdict(D(2027, 6, 1), None, 2085)
        self.assertTrue(ok)
        self.assertIn("done", message)


class LastChecked(unittest.TestCase):
    def test_reads_a_date(self):
        self.assertEqual(cpr.last_checked("x\nlast_checked: 2027-01-10\ny"), D(2027, 1, 10))

    def test_none_means_never(self):
        self.assertIsNone(cpr.last_checked("last_checked: none\n"))

    def test_missing_line_exits(self):
        with self.assertRaises(SystemExit):
            cpr.last_checked("nothing here")

    def test_malformed_date_exits(self):
        with self.assertRaises(SystemExit):
            cpr.last_checked("last_checked: soon\n")


class TheCommittedProcedure(unittest.TestCase):
    def test_carries_a_readable_last_checked_line(self):
        cpr.last_checked(cpr.PROCEDURE.read_text(encoding="utf-8"))


if __name__ == "__main__":
    unittest.main()
