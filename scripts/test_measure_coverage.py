#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Dibas Sigdel
"""Tests for the coverage parser in `measure-coverage.py`.

That script produces the published coverage figures (including the OpenSSF badge
answers); `docs/coverage.md` records three earlier bugs in it that each gave a
wrong number. These tests feed it a recorded llvm-cov report table and pin what
it counts, what it ignores and how it combines suites.
"""

from __future__ import annotations

import importlib.util
import unittest
from pathlib import Path

_SCRIPT = Path(__file__).resolve().parent / "measure-coverage.py"
_spec = importlib.util.spec_from_file_location("measure_coverage", _SCRIPT)
mc = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(mc)

CORE = "NepalKitCore/Sources/NepalKitCore/"
APP = "NepalKit/"

# llvm-cov prints the repository path with its leading "/" stripped.
ROOT = str(mc.REPO_ROOT).lstrip("/") + "/"


def row(path: str, lines: int, missed: int, functions: str = "4 1 75.00%") -> str:
    """One 13-field llvm-cov row: name, then regions, functions, lines, branches."""
    pct = f"{100 * (lines - missed) / lines:.2f}%" if lines else "-"
    return f"{ROOT}{path} 10 2 80.00% {functions} {lines} {missed} {pct} 0 0 -"


FIXTURE = "\n".join(
    [
        "Filename Regions Missed Regions Cover Functions Missed Functions "
        "Executed Lines Missed Lines Cover Branches Missed Branches Cover",
        "-" * 60,
        row(CORE + "A.swift", 100, 10),
        row(CORE + "B.swift", 50, 50),
        row(APP + "C.swift", 200, 140),
        row(APP + "D.swift", 300, 300),
        row("NepalKitTests/T.swift", 999, 0),
        "-" * 60,
        "TOTAL 10 2 80.00% 4 1 75.00% 1649 500 69.00% 0 0 -",
    ]
)

CORE_ONLY = (CORE,)
APP_ONLY = (APP,)


class SummariseTests(unittest.TestCase):
    def test_only_rows_under_the_given_prefixes_count(self):
        """The app prefix keeps app rows and drops core, test, header and TOTAL rows."""
        counts = mc.summarise(FIXTURE, APP_ONLY)
        self.assertEqual(counts["files"], 2)
        self.assertEqual(counts["lines"], 500)
        self.assertEqual(counts["lines_hit"], 60)

    def test_core_prefix_selects_core_rows(self):
        counts = mc.summarise(FIXTURE, CORE_ONLY)
        self.assertEqual(counts["files"], 2)
        self.assertEqual(counts["lines"], 150)
        self.assertEqual(counts["lines_hit"], 90)

    def test_both_prefixes_select_all_product_rows(self):
        """Both prefixes select all four rows, so the gate must not give both to one suite."""
        counts = mc.summarise(FIXTURE, CORE_ONLY + APP_ONLY)
        self.assertEqual(counts["files"], 4)

    def test_a_dash_column_is_positional_not_dropped(self):
        """A "-" (no data) must not be dropped, or every later column shifts."""
        report = row(APP + "E.swift", 20, 5, functions="- - -")
        counts = mc.summarise(report, APP_ONLY)
        self.assertEqual(counts["functions"], 0)
        self.assertEqual(counts["functions_hit"], 0)
        self.assertEqual(counts["lines"], 20)
        self.assertEqual(counts["lines_hit"], 15)
        self.assertEqual(counts["regions"], 10)
        self.assertEqual(counts["regions_hit"], 8)

    def test_an_empty_report_is_all_zeros(self):
        counts = mc.summarise("", APP_ONLY)
        self.assertEqual(set(counts.values()), {0})


class PercentageTests(unittest.TestCase):
    def test_percentages_round_to_two_places(self):
        result = mc.percentages(
            {"regions": 3, "regions_hit": 1, "functions": 7, "functions_hit": 2,
             "lines": 3, "lines_hit": 2, "files": 5}
        )
        self.assertEqual(result["lines"], 66.67)
        self.assertEqual(result["regions"], 33.33)
        self.assertEqual(result["functions"], 28.57)
        self.assertEqual(result["files"], 5)

    def test_zero_denominators_are_zero_not_an_error(self):
        result = mc.percentages(mc.summarise("", APP_ONLY))
        self.assertEqual(result["lines"], 0.0)
        self.assertEqual(result["files"], 0)


class CombinationTests(unittest.TestCase):
    def test_combined_is_line_weighted(self):
        """Core 90/150 and app 60/500 lines give 150/650 = 23.08%; a file-weighted
        mean of 60% and 12% would say 36%."""
        core = mc.summarise(FIXTURE, CORE_ONLY)
        app = mc.summarise(FIXTURE, APP_ONLY)
        combined = mc.combine([core, app])
        self.assertEqual(combined["lines"], 650)
        self.assertEqual(combined["lines_hit"], 150)
        self.assertEqual(mc.percentages(combined)["lines"], 23.08)


class RegressionTests(unittest.TestCase):
    FLOOR = {
        "totals": {"lines": 40.0, "regions": 50.0, "functions": 50.0, "files": 4},
        "suites": {
            "core": {"lines": 80.0, "regions": 70.0, "functions": 70.0, "files": 2},
            "app": {"lines": 30.0, "regions": 40.0, "functions": 40.0, "files": 2},
        },
    }

    def test_no_regression_reports_nothing(self):
        self.assertEqual(
            mc.regressions(self.FLOOR["totals"], self.FLOOR["suites"], self.FLOOR), []
        )

    def test_per_suite_regressions_are_reported(self):
        """An app drop must fail even when a core gain keeps the total level."""
        suites = {
            "core": {"lines": 90.0, "regions": 70.0, "functions": 70.0, "files": 2},
            "app": {"lines": 20.0, "regions": 40.0, "functions": 40.0, "files": 2},
        }
        found = mc.regressions(self.FLOOR["totals"], suites, self.FLOOR)
        self.assertEqual(len(found), 1)
        self.assertTrue(found[0].startswith("app lines:"), found)

    def test_total_regressions_are_reported(self):
        totals = dict(self.FLOOR["totals"], regions=10.0)
        found = mc.regressions(totals, self.FLOOR["suites"], self.FLOOR)
        self.assertEqual(len(found), 1)
        self.assertTrue(found[0].startswith("combined regions:"), found)

    def test_the_half_hundredth_tolerance_holds(self):
        totals = dict(self.FLOOR["totals"], lines=39.996)
        self.assertEqual(mc.regressions(totals, self.FLOOR["suites"], self.FLOOR), [])


if __name__ == "__main__":
    unittest.main()
