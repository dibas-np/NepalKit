#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Dibas Sigdel
"""Tests for `verify-deployment-floor.py`.

The script's whole reason to exist is a bug that shipped, so the tests are
weighted towards the failure paths: every way the floor can drift has to be
provable, because "the sources agree" is a claim that was once false and every
gate was green while it was.
"""

from __future__ import annotations

import contextlib
import importlib.util
import io
import os
import plistlib
import sys
import tempfile
import unittest
from pathlib import Path

MODULE_PATH = Path(__file__).resolve().parent / "verify-deployment-floor.py"
_spec = importlib.util.spec_from_file_location("verify_deployment_floor", MODULE_PATH)
assert _spec and _spec.loader
vdf = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(vdf)

PBXPROJ = (
    "// !$*UTF8*$!\n"
    "{ objects = 1A2B3C /* Begin XCBuildConfiguration section */\n"
    "\t\t1111 /* Debug */ = {\n"
    "\t\t\tisa = XCBuildConfiguration;\n"
    "\t\t\tbuildSettings = {\n"
    "\t\t\t\tMACOSX_DEPLOYMENT_TARGET = 26.6;\n"
    "\t\t\t};\n"
    "\t\t};\n"
    "\t\t2222 /* Release */ = {\n"
    "\t\t\tisa = XCBuildConfiguration;\n"
    "\t\t\tbuildSettings = {\n"
    "\t\t\t\tMACOSX_DEPLOYMENT_TARGET = 26.0;\n"
    "\t\t\t};\n"
    "\t\t};\n"
    "/* End XCBuildConfiguration section */\n"
    "}\n"
)

RELEASE_SH = "#!/bin/sh\nDEPLOYMENT_TARGET=26.6\nARCHIVE=x\n"


class ProjectFloorParsingTests(unittest.TestCase):
    def test_finds_every_configuration_block_that_declares_a_floor(self) -> None:
        found = vdf.project_floors(PBXPROJ)
        self.assertEqual([26.6, 26.0].count(26.6), 1)
        self.assertEqual(len(found), 2, "both blocks declare a floor and both must be found")

    def test_reports_the_line_so_a_failure_can_name_what_to_edit(self) -> None:
        found = vdf.project_floors(PBXPROJ)
        lines = [line for line, _ in found]
        for _, value in found:
            self.assertEqual(PBXPROJ.splitlines()[_ - 1].strip(),
                             f"MACOSX_DEPLOYMENT_TARGET = {value};",
                             f"line {_} does not contain the value reported for it")

    def test_a_block_without_the_key_is_not_a_floor(self) -> None:
        # Absence means "inherit", and the project level is where inheritance
        # resolves. Treating an absent key as a value would invent a floor nobody
        # wrote down, and the gate would then fail on configurations that are
        # correct by not overriding anything.
        no_key = PBXPROJ.replace("\t\t\t\tMACOSX_DEPLOYMENT_TARGET = 26.6;\n", "")
        remaining = vdf.project_floors(no_key)
        self.assertEqual([value for _, value in remaining], ["26.0"],
                         "only the block that still declares a floor is reported")


class ReleaseScriptFloorParsingTests(unittest.TestCase):
    def test_reads_the_declared_target(self) -> None:
        line, value = vdf.release_script_floor(RELEASE_SH)
        self.assertEqual(value, "26.6")
        self.assertIn("DEPLOYMENT_TARGET", RELEASE_SH.splitlines()[line - 1])

    def test_a_target_inside_a_comment_is_not_the_declaration(self) -> None:
        # `#DEPLOYMENT_TARGET=26.0` commented out above the real one must not win.
        commented = "#DEPLOYMENT_TARGET=26.0\n" + RELEASE_SH
        line, value = vdf.release_script_floor(commented)
        self.assertEqual(value, "26.6", "the commented-out line must not be read")
        self.assertTrue(commented.splitlines()[line - 1].startswith("DEPLOYMENT_TARGET"))


class BuiltProductFloorTests(unittest.TestCase):
    def _plist(self, value: object) -> Path:
        directory = Path(tempfile.mkdtemp())
        path = directory / "Info.plist"
        with path.open("wb") as handle:
            plistlib.dump({"LSMinimumSystemVersion": value} if value is not None else {}, handle)
        return path

    def test_reads_the_expanded_value_from_a_built_product(self) -> None:
        self.assertEqual(vdf.product_floor(self._plist("26.6")), "26.6")

    def test_an_unexpanded_token_is_not_mistaken_for_a_floor(self) -> None:
        # The source Info.plist carries this. A text search over it would return
        # the token and call it a value; plistlib returns it too, so the check is
        # that the caller sees the token and the *comparison* fails loudly rather
        # than the token being silently accepted as "some floor".
        self.assertEqual(vdf.product_floor(self._plist("$(MACOSX_DEPLOYMENT_TARGET)")),
                         "$(MACOSX_DEPLOYMENT_TARGET)")

    def test_a_product_with_no_floor_key_reads_as_absent_not_as_empty(self) -> None:
        self.assertIsNone(vdf.product_floor(self._plist(None)))

    def test_an_unreadable_path_is_absent_not_an_error(self) -> None:
        self.assertIsNone(vdf.product_floor(Path("/nonexistent/Info.plist")))


class DriftDetectionTests(unittest.TestCase):
    """The bug, reproduced: one source out of step must be a non-zero exit."""

    def _run(self, project: str, release: str, built: str | None) -> tuple[int, str]:
        captured = io.StringIO()
        code = 0
        with contextlib.redirect_stdout(captured):
            with self._patch_sources(project, release, built):
                code = vdf.main()
        return code, captured.getvalue()

    @contextlib.contextmanager
    def _patch_sources(self, project: str, release: str, built: str | None):
        original_project, original_release = vdf.PROJECT, vdf.RELEASE_SCRIPT
        original_locate = vdf._locate_built_product
        original_plist = vdf.product_floor
        project_path = Path(tempfile.mkdtemp()) / "project.pbxproj"
        project_path.write_text(project, encoding="utf-8")
        release_path = Path(tempfile.mkdtemp()) / "package-release.sh"
        release_path.write_text(release, encoding="utf-8")
        vdf.PROJECT, vdf.RELEASE_SCRIPT = project_path, release_path
        # Both halves have to be patched. Returning None from the locator made the
        # patched product_floor unreachable, so a test for the built product
        # silently exercised the "no build" path and passed for the wrong reason.
        vdf._locate_built_product = (
            (lambda: Path("/fake/NepalKit.app/Contents/Info.plist"))
            if built is not None else (lambda: None)
        )
        if built is not None:
            vdf.product_floor = lambda _p: built
        try:
            yield
        finally:
            vdf.PROJECT, vdf.RELEASE_SCRIPT = original_project, original_release
            vdf._locate_built_product = original_locate
            vdf.product_floor = original_plist

    def test_all_sources_agreeing_passes(self) -> None:
        code, output = self._run(PBXPROJ.replace("26.0", "26.6"), RELEASE_SH, "26.6")
        self.assertEqual(code, 0, output)
        self.assertIn("everywhere it is written", output)

    def test_a_project_level_config_behind_the_app_target_fails(self) -> None:
        # The exact drift that shipped: Release at 26.0, everything else 26.6.
        code, output = self._run(PBXPROJ, RELEASE_SH, "26.6")
        self.assertEqual(code, 1, "a project-level config behind the target must fail")
        self.assertIn("NOT consistent", output)

    def test_the_release_script_behind_the_project_fails(self) -> None:
        code, output = self._run(
            PBXPROJ.replace("26.0", "26.6"), "DEPLOYMENT_TARGET=26.0\n", "26.6"
        )
        self.assertEqual(code, 1, "verify-appcast.py trusts this file; it must agree")

    def test_a_built_product_behind_both_sources_fails(self) -> None:
        # The bug's user-visible form: sources agree with each other and all
        # three are wrong about what shipped.
        code, output = self._run(
            PBXPROJ.replace("26.0", "26.6"), RELEASE_SH, "26.0"
        )
        self.assertEqual(code, 1, "the built product is the ground truth, not a bystander")
        self.assertIn("built product", output)

    def test_every_disagreeing_source_is_named_not_just_the_first(self) -> None:
        code, output = self._run(PBXPROJ, "DEPLOYMENT_TARGET=26.1\n", "26.0")
        self.assertEqual(code, 1)
        for expected in ("26.6", "26.0", "26.1"):
            self.assertIn(expected, output, f"{expected} missing from the report")

    def test_a_release_script_with_no_target_is_a_failure_not_a_skip(self) -> None:
        # Without it verify-appcast.py compares the feed against nothing, so its
        # "matches the app's floor" line becomes meaningless rather than absent.
        code, output = self._run(PBXPROJ.replace("26.0", "26.6"), "#!/bin/sh\nARCHIVE=x\n", None)
        self.assertNotEqual(code, 0)
        self.assertIn("DEPLOYMENT_TARGET", output)

    def test_the_format_xcode_27_writes_is_the_one_ci_can_read(self) -> None:
        # CI runs on the xcode-27 image, so 110 is correct here rather than
        # something to fix. A ceiling below it would fail on every commit where a
        # maintainer edited build settings, because Xcode rewrites the format
        # merely by opening the project - the gate would be fighting the tool.
        # This is the positive control for the ceiling: the version Xcode 27
        # actually writes must be the version the gate accepts.
        self.assertEqual(vdf.MAX_OBJECT_VERSION, 110)
        self.assertIsNone(vdf._project_format_problem("\tobjectVersion = 110;\n"))

    def test_a_format_newer_than_ci_can_read_is_a_failure_not_a_pass(self) -> None:
        # The failure this gate exists for, in the shape it will next take: a
        # future Xcode adopts format 111 and rewrites the project on open. CI's
        # toolchain cannot read it, so the job fails with "Unable to read
        # project" - which names neither the setting nor the file to change.
        # Here it must fail with a message that names both.
        problem = vdf._project_format_problem("\tobjectVersion = 111;\n")
        self.assertIsNotNone(problem, "a format CI cannot read must not pass")
        self.assertIn("110", problem, "the message has to say what the ceiling is")
        self.assertIn("xcode-27", problem, "the message has to say which runner")

    def test_a_110_project_is_not_rejected_by_the_message_a_check_would_give(self) -> None:
        # The negative control for the negative control: the exact state this
        # branch originally shipped - objectVersion 110 - used to be the failure.
        # If the ceiling ever drops back below 110 this fails, which is the point:
        # it makes the mistake loud here rather than as a red CI job.
        self.assertIsNone(
            vdf._project_format_problem(PBXPROJ.split("\n", 0)[0] + "\n" + PBXPROJ),
            "110 is what Xcode 27 writes and CI reads it; it must not fail",
        )

    def test_a_project_within_the_limit_reports_nothing(self) -> None:
        self.assertIsNone(vdf._project_format_problem("\tobjectVersion = 100;\n"))

    def test_the_probe_the_other_tests_use_is_one_this_gate_can_actually_parse(self) -> None:
        # Written after two of these tests passed for the wrong reason: the probe
        # strings were prefixed "// ", which the object's regex does not match, so
        # assertIsNone was returning None because nothing had been parsed rather
        # than because the version was accepted. A test that cannot fail is worse
        # than no test, because it is evidence. This asserts the probe is read.
        self.assertEqual(
            vdf._project_format_problem("\tobjectVersion = 111;\n") is not None,
            True,
            "if this fails, every version test above is passing vacuously",
        )

    def test_a_project_with_no_object_version_is_not_a_failure(self) -> None:
        # Absent means an older format this gate has no opinion about, and
        # failing on it would make the gate refuse a project it cannot judge.
        self.assertIsNone(vdf._project_format_problem("{ objects = 1; }\n"))

    def test_the_gate_passes_with_no_built_product(self) -> None:
        # A clean checkout that has never been built must not be blocked by a
        # gate about a build it does not have.
        code, output = self._run(PBXPROJ.replace("26.0", "26.6"), RELEASE_SH, None)
        self.assertEqual(code, 0, output)
        self.assertNotIn("built product", output)


class RealRepositoryTests(unittest.TestCase):
    """The committed tree, which is the state the gate actually runs on."""

    def test_the_repository_floor_is_consistent(self) -> None:
        captured = io.StringIO()
        with contextlib.redirect_stdout(captured):
            code = vdf.main()
        self.assertEqual(code, 0, captured.getvalue())

    def test_the_repository_project_format_is_one_the_floor_job_can_read(self) -> None:
        # ADR-0007: object version 110 is Xcode 27's format, the floor job pins
        # Xcode 26.6, and Xcode 26 cannot open a 110 project at all. It has
        # regressed twice - once deliberately in a406c7e, once by accident when
        # Xcode 27 rewrote the file merely by opening it.
        with contextlib.redirect_stdout(io.StringIO()):
            problem = vdf._project_format_problem(
                vdf.PROJECT.read_text(encoding="utf-8"))
        self.assertIsNone(problem, problem or "")

    def test_the_release_script_floor_is_what_the_verifier_reads(self) -> None:
        # Ties this gate to the other one. If verify-appcast.py's notion of the
        # floor is the file this gate checks, agreement here is agreement there.
        verifier = (vdf.REPO_ROOT / "scripts" / "verify-appcast.py").read_text(encoding="utf-8")
        self.assertIn("package-release.sh", verifier)
        self.assertIn("DEPLOYMENT_TARGET", verifier)


if __name__ == "__main__":
    unittest.main()
