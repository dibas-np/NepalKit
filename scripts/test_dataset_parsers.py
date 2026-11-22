#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Dibas Sigdel

from __future__ import annotations

import importlib.util
import tempfile
import unittest
from pathlib import Path

import dataset_table

HERE = Path(__file__).resolve().parent


def load(name):
    spec = importlib.util.spec_from_file_location(name.replace("-", "_"), HERE / name)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


vds = load("verify-data-sources.py")
ckc = load("check-kathmandu-calendar.py")


DATASET_HEADER = """\
// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Dibas Sigdel
/// A versioned Bikram Sambat month-length table with its conversion anchor.
///
/// Provenance is documented in `SOURCES.md` at the repository root.
public struct CalendarDataset {
    public let years: [Int: [Int]]
    /// A doc example that looks like data but is not the shipped table.
    /// 1970: [31, 31, 32, 32, 31, 30, 30, 29, 30, 29, 30, 30],
    public static let v2 = CalendarDataset(
        version: "2.0.0",
        years: [
            1975: [31, 31, 32, 32, 31, 30, 30, 29, 30, 29, 30, 30],
            1976: [31, 32, 31, 32, 31, 30, 30, 30, 29, 29, 30, 31],
            1977: [30, 32, 31, 32, 31, 30, 30, 30, 29, 30, 29, 31],
        ],
        anchorBikramSambat: BikramSambatDate(year: 1975, month: 1, day: 1)
    )
}
"""

SHIPPED_ROWS = {
    1975: [31, 31, 32, 32, 31, 30, 30, 29, 30, 29, 30, 30],
    1976: [31, 32, 31, 32, 31, 30, 30, 30, 29, 29, 30, 31],
    1977: [30, 32, 31, 32, 31, 30, 30, 30, 29, 30, 29, 31],
}

ASKBUDDIE_BODY = """\
/**
 * This includes the number of days in each month for each year from 1975 to 2100 BS.
 */
export const DaysInMonthsMappingData = {
  '1975': [31, 31, 32, 32, 31, 30, 30, 29, 30, 29, 30, 30],
  '1976': [31, 32, 31, 32, 31, 30, 30, 30, 29, 29, 30, 31],
}
"""


class ShippedTableTests(unittest.TestCase):
    def parse(self, text):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "CalendarDataset.swift"
            path.write_text(text, encoding="utf-8")
            return dataset_table.shipped_table(path)

    def test_reads_only_the_indented_literal(self):
        self.assertEqual(self.parse(DATASET_HEADER), SHIPPED_ROWS)

    def test_exits_when_no_years_block(self):
        text = "public struct CalendarDataset {\n    public let years: [Int: [Int]]\n}\n"
        with self.assertRaisesRegex(SystemExit, "format changed"):
            self.parse(text)

    def test_exits_when_years_block_has_no_rows(self):
        text = DATASET_HEADER.replace(
            """\
            1975: [31, 31, 32, 32, 31, 30, 30, 29, 30, 29, 30, 30],
            1976: [31, 32, 31, 32, 31, 30, 30, 30, 29, 29, 30, 31],
            1977: [30, 32, 31, 32, 31, 30, 30, 30, 29, 30, 29, 31],
""",
            "",
        )
        with self.assertRaisesRegex(SystemExit, "format changed"):
            self.parse(text)


class SourceParserTests(unittest.TestCase):
    def test_askbuddie_quoted_year_rows(self):
        self.assertEqual(
            vds.parse_askbuddie(ASKBUDDIE_BODY),
            {
                1975: [31, 31, 32, 32, 31, 30, 30, 29, 30, 29, 30, 30],
                1976: [31, 32, 31, 32, 31, 30, 30, 30, 29, 29, 30, 31],
            },
        )


class MonthLengthsTests(unittest.TestCase):
    def test_complete_year(self):
        days = {month: set(range(30)) for month in range(1, 13)}
        self.assertEqual(ckc.month_lengths(days), [30] * 12)

    def test_stray_month_13_and_missing_month_12(self):
        days = {month: set(range(30)) for month in range(1, 12)}
        days[13] = set(range(30))
        self.assertIsNone(ckc.month_lengths(days))

    def test_months_one_to_eleven_only(self):
        days = {month: set(range(30)) for month in range(1, 12)}
        self.assertIsNone(ckc.month_lengths(days))


class ShippedRangeTests(unittest.TestCase):
    def test_shipped_table_shape(self):
        rows = dataset_table.shipped_table()
        self.assertEqual(len(rows), 110)
        self.assertEqual(min(rows), 1975)
        self.assertEqual(max(rows), 2084)
        self.assertTrue(all(len(lengths) == 12 for lengths in rows.values()))


def gate_fixture():
    return {
        "shipped": {"first": 1975, "last": 2084, "years": 110},
        "sources": {
            "base-fixture": {
                "shared": 110, "exact": 107, "uncovered": [],
                "diffs": [[1975, 4], [1975, 5], [1991, 7], [1991, 8],
                          [2062, 0], [2062, 1]],
            },
            "partial-fixture": {
                "shared": 106, "exact": 104, "uncovered": [1975, 1976, 1977, 1978],
                "diffs": [[1991, 7], [1991, 8], [2062, 0], [2062, 1]],
            },
        },
    }


class ProvenanceGateDecisionTests(unittest.TestCase):
    def test_an_observation_equal_to_the_baseline_reports_no_problem(self):
        expected = gate_fixture()
        observed = gate_fixture()
        self.assertEqual(vds._compare_observations(observed, expected), [])

    def test_recorded_differences_are_not_themselves_a_problem(self):
        expected = gate_fixture()
        observed = gate_fixture()
        self.assertEqual(observed["sources"]["base-fixture"]["diffs"],
                         [[1975, 4], [1975, 5], [1991, 7], [1991, 8], [2062, 0], [2062, 1]])
        self.assertEqual(vds._compare_observations(observed, expected), [])

    def test_a_narrowed_shipped_range_is_reported(self):
        expected = gate_fixture()
        observed = gate_fixture()
        observed["shipped"] = {"first": 1975, "last": 2083, "years": 109}
        self.assertEqual(vds._compare_observations(observed, expected), [
            "shipped range changed: "
            "baseline {'first': 1975, 'last': 2084, 'years': 110}, "
            "live {'first': 1975, 'last': 2083, 'years': 109}",
        ])

    def test_a_widened_shipped_range_is_reported(self):
        expected = gate_fixture()
        observed = gate_fixture()
        observed["shipped"] = {"first": 1975, "last": 2085, "years": 111}
        self.assertEqual(vds._compare_observations(observed, expected), [
            "shipped range changed: "
            "baseline {'first': 1975, 'last': 2084, 'years': 110}, "
            "live {'first': 1975, 'last': 2085, 'years': 111}",
        ])

    def test_a_source_the_baseline_does_not_record_is_reported(self):
        expected = gate_fixture()
        observed = gate_fixture()
        del expected["sources"]["partial-fixture"]
        self.assertEqual(vds._compare_observations(observed, expected), [
            "partial-fixture: new source not in baseline (shared=106, exact=104)",
        ])

    def test_a_source_the_live_observation_is_missing_is_reported(self):
        expected = gate_fixture()
        observed = gate_fixture()
        del observed["sources"]["base-fixture"]
        self.assertEqual(vds._compare_observations(observed, expected), [
            "base-fixture: missing from live observation",
        ])

    def test_a_changed_exact_year_count_is_reported(self):
        expected = gate_fixture()
        observed = gate_fixture()
        observed["sources"]["base-fixture"]["exact"] = 108
        self.assertEqual(vds._compare_observations(observed, expected), [
            "base-fixture: exact years changed: baseline 107, live 108",
        ])

    def test_a_changed_shared_year_count_is_reported(self):
        expected = gate_fixture()
        observed = gate_fixture()
        observed["sources"]["base-fixture"]["shared"] = 109
        self.assertEqual(vds._compare_observations(observed, expected), [
            "base-fixture: shared years changed: baseline 110, live 109",
        ])

    def test_a_newly_differing_month_is_reported(self):
        expected = gate_fixture()
        observed = gate_fixture()
        observed["sources"]["base-fixture"]["diffs"].append([2084, 0])
        self.assertEqual(vds._compare_observations(observed, expected), [
            "base-fixture: new differing month 2084 Baisakh [2084, 0] not in baseline",
        ])

    def test_a_vanished_differing_month_is_reported(self):
        expected = gate_fixture()
        observed = gate_fixture()
        observed["sources"]["base-fixture"]["diffs"].remove([1975, 4])
        self.assertEqual(vds._compare_observations(observed, expected), [
            "base-fixture: vanished differing month 1975 Bhadra [1975, 4] "
            "recorded in baseline but not observed",
        ])

    def test_a_newly_uncovered_year_is_reported(self):
        expected = gate_fixture()
        observed = gate_fixture()
        observed["sources"]["partial-fixture"]["uncovered"].append(1979)
        self.assertEqual(vds._compare_observations(observed, expected), [
            "partial-fixture: newly uncovered year 1979 not in baseline",
        ])

    def test_a_year_that_is_no_longer_uncovered_is_reported(self):
        expected = gate_fixture()
        observed = gate_fixture()
        observed["sources"]["partial-fixture"]["uncovered"].remove(1978)
        self.assertEqual(vds._compare_observations(observed, expected), [
            "partial-fixture: vanished uncovered year 1978 recorded in baseline but now covered",
        ])


class ProvenanceGateArgvTests(unittest.TestCase):
    def test_no_flag_leaves_every_option_unset(self):
        self.assertEqual(vds._parse_argv([]), (False, None, None))

    def test_baseline_with_a_separate_path(self):
        offline, baseline, update = vds._parse_argv(["--baseline", "other.json"])
        self.assertFalse(offline)
        self.assertEqual(baseline, Path("other.json"))
        self.assertIsNone(update)

    def test_baseline_with_an_equals_sign(self):
        offline, baseline, update = vds._parse_argv(["--baseline=other.json"])
        self.assertFalse(offline)
        self.assertEqual(baseline, Path("other.json"))
        self.assertIsNone(update)

    def test_a_bare_update_baseline_means_the_committed_default(self):
        offline, baseline, update = vds._parse_argv(["--update-baseline"])
        self.assertFalse(offline)
        self.assertIsNone(baseline)
        self.assertEqual(update, Path("scripts/data-sources-baseline.json"))
        self.assertEqual(update, vds.DEFAULT_BASELINE)

    def test_update_baseline_with_an_equals_sign(self):
        offline, baseline, update = vds._parse_argv(["--update-baseline=other.json"])
        self.assertFalse(offline)
        self.assertIsNone(baseline)
        self.assertEqual(update, Path("other.json"))

    def test_offline_alone_asks_for_no_comparison(self):
        self.assertEqual(vds._parse_argv(["--offline"]), (True, None, None))

    def test_a_baseline_without_a_path_exits_rather_than_defaulting(self):
        with self.assertRaises(SystemExit):
            vds._parse_argv(["--baseline"])


if __name__ == "__main__":
    unittest.main()
