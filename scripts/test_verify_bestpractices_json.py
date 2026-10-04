#!/usr/bin/env python3
"""Test suite for scripts/verify-bestpractices-json.py.

Run: python3 scripts/test_verify_bestpractices_json.py

Exists because the gate it covers is not run by any other check in this
repository's local list, and an unexercised gate is a gate that rots. The
failures below are the ones a plausible edit to .bestpractices.json could
produce: a mistyped status, a status added without its justification, a
justification blanked while its status stays, and - the one that matters most -
both halves of one answer deleted, which no structural check can see.

The suite imports check() and calls it with a Path rather than spawning the
script with a path argument. That is why the script has no path argument: a
CLI that reads whatever path it is handed is a path-injection surface, and
SonarCloud flagged exactly that when this gate was first written. Testing
through the function keeps the untrusted-argv surface out of existence instead
of documenting around it.
"""

from __future__ import annotations

import importlib.util
import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
VERIFIER = REPO_ROOT / "scripts" / "verify-bestpractices-json.py"
ENTRY = REPO_ROOT / ".bestpractices.json"

_spec = importlib.util.spec_from_file_location("verify_bestpractices_json", VERIFIER)
assert _spec and _spec.loader
verifier = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(verifier)


def write(document: object, directory: str) -> Path:
    path = Path(directory) / ".bestpractices.json"
    path.write_text(json.dumps(document), encoding="utf-8")
    return path


class StructuralTest(unittest.TestCase):
    """Cases that do not need the full 64-criterion set."""

    def check(self, document: object) -> list[str]:
        with tempfile.TemporaryDirectory() as directory:
            problems, _ = verifier.check(write(document, directory))
            return problems

    def test_a_status_with_no_justification_fails(self) -> None:
        problems = self.check({"osps_ac_01_01_status": "Met"})
        self.assertTrue(any("has a status but no justification" in p for p in problems))

    def test_a_justification_with_no_status_fails(self) -> None:
        problems = self.check({"osps_ac_01_01_justification": "because"})
        self.assertTrue(any("has a justification but no status" in p for p in problems))

    def test_an_unknown_status_value_fails(self) -> None:
        problems = self.check(
            {"osps_ac_01_01_status": "Mostly", "osps_ac_01_01_justification": "because"}
        )
        self.assertTrue(any("is not one of" in p for p in problems))

    def test_a_non_string_status_fails(self) -> None:
        problems = self.check(
            {"osps_ac_01_01_status": 1, "osps_ac_01_01_justification": "because"}
        )
        self.assertTrue(any("is not a string" in p for p in problems))

    def test_an_empty_justification_fails(self) -> None:
        problems = self.check(
            {"osps_ac_01_01_status": "Met", "osps_ac_01_01_justification": "   "}
        )
        self.assertTrue(any("is empty" in p for p in problems))

    def test_an_unknown_top_level_key_fails(self) -> None:
        problems = self.check({"notes": "hello"})
        self.assertTrue(
            any("neither a documented field nor a criterion field" in p for p in problems)
        )

    def test_a_non_criteria_field_is_accepted(self) -> None:
        problems = self.check(
            {
                "name": "NepalKit",
                "description": "A menu-bar app.",
                "license": "GPL-3.0-or-later",
                "implementation_languages": "Swift",
            }
        )
        self.assertEqual(problems, [])

    def test_a_question_mark_placeholder_is_accepted(self) -> None:
        problems = self.check(
            {
                "osps_ac_01_01_status": "?",
                "osps_ac_01_01_justification": "?",
                "osps_ac_02_01_status": "unknown",
                "osps_ac_02_01_justification": "unknown",
            }
        )
        self.assertEqual(problems, [])

    def test_a_capitalised_field_name_is_accepted(self) -> None:
        problems = self.check(
            {"require_2FA_status": "Unmet", "require_2FA_justification": "because"}
        )
        self.assertEqual(problems, [])

    def test_a_present_but_blank_justification_is_still_an_error(self) -> None:
        # '?' is ignored by the badge; an empty string is not the same thing. A
        # blank justification that is *present* reads as an assertion.
        problems = self.check(
            {"osps_ac_01_01_status": "?", "osps_ac_01_01_justification": ""}
        )
        self.assertTrue(any("is empty" in p for p in problems))

    def test_invalid_json_fails(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / ".bestpractices.json"
            path.write_text("{not json", encoding="utf-8")
            problems, _ = verifier.check(path)
        self.assertTrue(any("not valid JSON" in p for p in problems))

    def test_a_non_object_document_fails(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / ".bestpractices.json"
            path.write_text("[]", encoding="utf-8")
            problems, _ = verifier.check(path)
        self.assertTrue(any("must hold a JSON object" in p for p in problems))

    def test_a_missing_file_fails(self) -> None:
        problems, _ = verifier.check(Path("/nonexistent/.bestpractices.json"))
        self.assertTrue(any("does not exist" in p for p in problems))


class CompletenessTest(unittest.TestCase):
    """The case no structural check can reach on its own."""

    def test_the_real_entry_is_complete(self) -> None:
        problems, _ = verifier.check(ENTRY, require_complete=True)
        self.assertEqual(problems, [], "\n".join(problems))

    def test_removing_both_halves_of_one_criterion_is_detected(self) -> None:
        # The negative control this gate exists for. Deleting both halves leaves
        # no unmatched pair, so every structural check passes and the badge would
        # omit the answer with no error anywhere.
        document = json.loads(ENTRY.read_text(encoding="utf-8"))
        del document["osps_qa_07_01_status"]
        del document["osps_qa_07_01_justification"]
        with tempfile.TemporaryDirectory() as directory:
            problems, _ = verifier.check(write(document, directory), require_complete=True)
        self.assertTrue(
            any("osps_qa_07_01: absent" in p for p in problems),
            f"a silently missing criterion went undetected: {problems}",
        )
        self.assertTrue(
            any("Baseline series" in p for p in problems),
            "the absence message should name the series it belongs to",
        )

    def test_removing_both_halves_of_a_metal_criterion_is_detected(self) -> None:
        document = json.loads(ENTRY.read_text(encoding="utf-8"))
        del document["bus_factor_status"]
        del document["bus_factor_justification"]
        with tempfile.TemporaryDirectory() as directory:
            problems, _ = verifier.check(write(document, directory), require_complete=True)
        self.assertTrue(
            any("bus_factor: absent from the Metal series" in p for p in problems),
            f"a silently missing Metal criterion went undetected: {problems}",
        )

    def test_the_two_pinned_series_are_the_right_size_and_disjoint(self) -> None:
        self.assertEqual(len(verifier.BASELINE_CRITERIA), 64)
        self.assertEqual(len(verifier.METAL_CRITERIA), 127)
        self.assertEqual(len(verifier.EXPECTED_CRITERIA), 191)
        self.assertEqual(
            verifier.BASELINE_CRITERIA & verifier.METAL_CRITERIA,
            set(),
            "a field pinned in both series would be checked twice and read twice",
        )

    def test_every_pinned_baseline_name_is_an_osps_one(self) -> None:
        self.assertTrue(
            all(name.startswith("osps_") for name in verifier.BASELINE_CRITERIA)
        )

    def test_no_pinned_metal_name_looks_like_an_osps_one(self) -> None:
        offenders = [n for n in verifier.METAL_CRITERIA if n.startswith("osps_")]
        self.assertEqual(offenders, [])

    def test_the_two_capitalised_metal_fields_are_pinned(self) -> None:
        # The badge spells these require_2FA and secure_2FA, capitals included.
        # A shape check that demanded lower_snake_case rejected both, which would
        # have kept the two most security-relevant Metal answers out of the file.
        self.assertIn("require_2FA", verifier.METAL_CRITERIA)
        self.assertIn("secure_2FA", verifier.METAL_CRITERIA)

    def test_a_field_in_the_wrong_series_is_reported(self) -> None:
        document = json.loads(ENTRY.read_text(encoding="utf-8"))
        # osps_ prefixed name sitting in the Metal half of the file.
        document["osps_vm_99_99_status"] = "Met"
        document["osps_vm_99_99_justification"] = "because"
        with tempfile.TemporaryDirectory() as directory:
            problems, _ = verifier.check(write(document, directory), require_complete=True)
        self.assertTrue(
            any("not in either pinned criterion set" in p for p in problems), problems
        )

    def test_an_unexpected_criterion_is_reported(self) -> None:
        document = json.loads(ENTRY.read_text(encoding="utf-8"))
        document["osps_not_a_real_criterion_status"] = "Met"
        document["osps_not_a_real_criterion_justification"] = "because"
        with tempfile.TemporaryDirectory() as directory:
            problems, _ = verifier.check(write(document, directory), require_complete=True)
        self.assertTrue(
            any("not in either pinned criterion set" in p for p in problems), problems
        )


class ProcessTest(unittest.TestCase):
    """The gate as check-all.sh actually invokes it."""

    def test_running_the_script_succeeds_on_the_real_entry(self) -> None:
        result = subprocess.run(
            [sys.executable, str(VERIFIER)], capture_output=True, text=True
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("structurally valid", result.stdout)
        self.assertIn("complete against all 191 pinned criteria", result.stdout)
        self.assertIn("64 Baseline, 127 Metal", result.stdout)

    def test_a_path_argument_is_ignored(self) -> None:
        # The path-injection surface stays out of existence rather than being
        # documented around. Passing a path - even a broken one - must not change
        # what gets validated: the script checks the repository's own entry and
        # nothing else. If this ever starts honouring an argument, the surface
        # returns and the tests should be rewritten before it does.
        with tempfile.TemporaryDirectory() as directory:
            elsewhere = Path(directory) / "somewhere-else.json"
            elsewhere.write_text("{ this is not valid json", encoding="utf-8")
            result = subprocess.run(
                [sys.executable, str(VERIFIER), str(elsewhere)],
                capture_output=True,
                text=True,
            )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn(ENTRY.name, result.stdout)
        self.assertNotIn("somewhere-else.json", result.stdout)


if __name__ == "__main__":
    unittest.main(verbosity=2)
