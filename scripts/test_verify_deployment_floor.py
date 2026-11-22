#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Dibas Sigdel

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

import xcode_project  # noqa: E402

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

QUIET = "26.9"


def watch_pbxproj(*blocks: tuple[str, str | None, str]) -> str:
    text = (
        "// !$*UTF8*$!\n"
        "{ objects = 1A2B3C /* Begin XCBuildConfiguration section */\n"
    )
    for name, sdkroot, floor in blocks:
        text += f"\t\t1111 /* {name} */ = {{\n"
        text += "\t\t\tisa = XCBuildConfiguration;\n"
        text += "\t\t\tbuildSettings = {\n"
        if sdkroot is not None:
            text += f"\t\t\t\tSDKROOT = {sdkroot};\n"
        text += f"\t\t\t\tWATCHOS_DEPLOYMENT_TARGET = {floor};\n"
        text += "\t\t\t};\n"
        text += "\t\t};\n"
    return text + "/* End XCBuildConfiguration section */\n}\n"


def floor_lines(text: str, value: str) -> list[int]:
    needle = f"WATCHOS_DEPLOYMENT_TARGET = {value};"
    return [n for n, line in enumerate(text.splitlines(), start=1) if needle in line]


THREE_SHAPES = watch_pbxproj(
    ("Watch App Debug", "watchos", "26.6"),
    ("NepalKitComplications Debug", "watchos", "26.0"),
    ("NepalKit Mac App Debug", None, QUIET),
    ("NepalKitWatch Debug", "iphoneos", QUIET),
)


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
        no_key = PBXPROJ.replace("\t\t\t\tMACOSX_DEPLOYMENT_TARGET = 26.6;\n", "")
        remaining = vdf.project_floors(no_key)
        self.assertEqual([value for _, value in remaining], ["26.0"],
                         "only the block that still declares a floor is reported")


class WatchOSProjectFloorParsingTests(unittest.TestCase):
    def test_only_blocks_that_declare_their_own_watchos_sdkroot_are_floors(self) -> None:
        found = vdf.watchos_project_floors(THREE_SHAPES)
        self.assertEqual(
            [value for _, value in found], ["26.6", "26.0"],
            "the two watchos blocks are the floors; the inherited-SDKROOT and "
            "iphoneos blocks are not",
        )
        self.assertEqual(
            [line for line, _ in found],
            floor_lines(THREE_SHAPES, "26.6") + floor_lines(THREE_SHAPES, "26.0"),
            "each floor is reported at the line that holds it",
        )

    def test_the_reported_line_holds_the_value_it_is_reported_for(self) -> None:
        lines = THREE_SHAPES.splitlines()
        for line, value in vdf.watchos_project_floors(THREE_SHAPES):
            self.assertEqual(lines[line - 1].strip(),
                             f"WATCHOS_DEPLOYMENT_TARGET = {value};",
                             f"line {line} does not contain the value reported for it")

    def test_an_inherited_sdkroot_block_does_not_declare_a_watchos_floor(self) -> None:
        only_inherited = watch_pbxproj(("NepalKit Mac App Debug", None, QUIET))
        self.assertEqual(vdf.watchos_project_floors(only_inherited), [],
                         "no SDKROOT of its own means no watchOS floor")

    def test_the_watch_container_does_not_declare_a_watchos_floor(self) -> None:
        only_container = watch_pbxproj(("NepalKitWatch Debug", "iphoneos", QUIET))
        self.assertEqual(vdf.watchos_project_floors(only_container), [],
                         "SDKROOT = iphoneos is not a watchOS floor")

    def test_a_watchos_block_without_the_key_is_not_a_floor(self) -> None:
        no_key = watch_pbxproj(("Watch App Debug", "watchos", "26.6")).replace(
            "\t\t\t\tWATCHOS_DEPLOYMENT_TARGET = 26.6;\n", "")
        self.assertEqual(vdf.watchos_project_floors(no_key), [],
                         "a watchos block that declares no floor is skipped, not defaulted")

    def test_the_macOS_parser_still_ignores_a_watchos_key(self) -> None:
        both = watch_pbxproj(("Watch App Debug", "watchos", "26.6"))
        both = both.replace("\t\t\t\tWATCHOS_DEPLOYMENT_TARGET = 26.6;\n",
                            "\t\t\t\tMACOSX_DEPLOYMENT_TARGET = 26.6;\n"
                            "\t\t\t\tWATCHOS_DEPLOYMENT_TARGET = 26.6;\n")
        self.assertEqual([value for _, value in vdf.project_floors(both)], ["26.6"])
        self.assertEqual([value for _, value in vdf.watchos_project_floors(both)], ["26.6"])


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
        self.assertEqual(vdf.product_floor(self._plist("$(MACOSX_DEPLOYMENT_TARGET)")),
                         "$(MACOSX_DEPLOYMENT_TARGET)")

    def test_a_product_with_no_floor_key_reads_as_absent_not_as_empty(self) -> None:
        self.assertIsNone(vdf.product_floor(self._plist(None)))

    def test_an_unreadable_path_is_absent_not_an_error(self) -> None:
        self.assertIsNone(vdf.product_floor(Path("/nonexistent/Info.plist")))


class GateHarness:
    def _run(self, project: str, built: str | None) -> tuple[int, str]:
        captured = io.StringIO()
        code = 0
        with contextlib.redirect_stdout(captured):
            with self._patch_sources(project, built):
                code = vdf.main()
        return code, captured.getvalue()

    @contextlib.contextmanager
    def _patch_sources(self, project: str, built: str | None):
        original_project = vdf.PROJECT
        original_locate = vdf._locate_built_product
        original_plist = vdf.product_floor
        project_path = Path(tempfile.mkdtemp()) / "project.pbxproj"
        project_path.write_text(project, encoding="utf-8")
        vdf.PROJECT = project_path
        vdf._locate_built_product = (
            (lambda: Path("/fake/NepalKit.app/Contents/Info.plist"))
            if built is not None else (lambda: None)
        )
        if built is not None:
            vdf.product_floor = lambda _p: built
        try:
            yield
        finally:
            vdf.PROJECT = original_project
            vdf._locate_built_product = original_locate
            vdf.product_floor = original_plist

class DriftDetectionTests(GateHarness, unittest.TestCase):
    def test_all_sources_agreeing_passes(self) -> None:
        code, output = self._run(PBXPROJ.replace("26.0", "26.6"), "26.6")
        self.assertEqual(code, 0, output)
        self.assertIn("everywhere it is written", output)

    def test_a_project_level_config_behind_the_app_target_fails(self) -> None:
        code, output = self._run(PBXPROJ, "26.6")
        self.assertEqual(code, 1, "a project-level config behind the target must fail")
        self.assertIn("NOT consistent", output)

    def test_a_built_product_behind_both_sources_fails(self) -> None:
        code, output = self._run(
            PBXPROJ.replace("26.0", "26.6"), "26.0"
        )
        self.assertEqual(code, 1, "the built product is the ground truth, not a bystander")
        self.assertIn("built product", output)

    def test_every_disagreeing_source_is_named_not_just_the_first(self) -> None:
        code, output = self._run(PBXPROJ, "26.1")
        self.assertEqual(code, 1)
        for expected in ("26.6", "26.0", "26.1"):
            self.assertIn(expected, output, f"{expected} missing from the report")

    def test_the_format_xcode_27_writes_is_the_one_ci_can_read(self) -> None:
        self.assertEqual(vdf.MAX_OBJECT_VERSION, 110)
        self.assertIsNone(vdf._project_format_problem("\tobjectVersion = 110;\n"))

    def test_a_format_newer_than_ci_can_read_is_a_failure_not_a_pass(self) -> None:
        problem = vdf._project_format_problem("\tobjectVersion = 111;\n")
        self.assertIsNotNone(problem, "a format CI cannot read must not pass")
        self.assertIn("110", problem, "the message has to say what the ceiling is")
        self.assertIn("xcode-27", problem, "the message has to say which runner")

    def test_a_110_project_is_not_rejected_by_the_message_a_check_would_give(self) -> None:
        self.assertIsNone(
            vdf._project_format_problem(PBXPROJ.split("\n", 0)[0] + "\n" + PBXPROJ),
            "110 is what Xcode 27 writes and CI reads it; it must not fail",
        )

    def test_a_project_within_the_limit_reports_nothing(self) -> None:
        self.assertIsNone(vdf._project_format_problem("\tobjectVersion = 100;\n"))

    def test_the_probe_the_other_tests_use_is_one_this_gate_can_actually_parse(self) -> None:
        self.assertEqual(
            vdf._project_format_problem("\tobjectVersion = 111;\n") is not None,
            True,
            "if this fails, every version test above is passing vacuously",
        )

    def test_a_project_with_no_object_version_is_not_a_failure(self) -> None:
        self.assertIsNone(vdf._project_format_problem("{ objects = 1; }\n"))

    def test_watchos_blocks_that_disagree_fail_and_name_both(self) -> None:
        code, output = self._run(THREE_SHAPES, "26.6")
        self.assertEqual(code, 1, "two watchOS blocks at different floors must fail")
        for value in ("26.6", "26.0"):
            self.assertIn(value, output, f"{value} missing from the report")

    def test_all_watchos_blocks_agreeing_passes(self) -> None:
        agreeing = watch_pbxproj(
            ("Watch App Debug", "watchos", "26.6"),
            ("NepalKitComplications Debug", "watchos", "26.6"),
        )
        code, output = self._run(agreeing, "26.6")
        self.assertEqual(code, 0, output)
        for line in floor_lines(agreeing, "26.6"):
            self.assertIn(f"project.pbxproj:{line}", output,
                          "an agreeing watchOS block must still be reported")

    def test_a_stale_watchos_key_on_an_inherited_sdkroot_block_is_silent(self) -> None:
        mixed = watch_pbxproj(
            ("Watch App Debug", "watchos", "26.6"),
            ("NepalKit Mac App Debug", None, QUIET),
        )
        code, output = self._run(mixed, "26.6")
        self.assertEqual(code, 0, output)
        self.assertIn(f"project.pbxproj:{floor_lines(mixed, '26.6')[0]}", output,
                      "the watchos block must be reported")
        self.assertNotIn(QUIET, output,
                         "a block that inherits its SDKROOT declares no watchOS floor")
        self.assertNotIn(f"project.pbxproj:{floor_lines(mixed, QUIET)[0]}", output,
                         "the inherited-SDKROOT block must not be named as a source")

    def test_a_watchos_key_on_the_watch_container_is_silent(self) -> None:
        mixed = watch_pbxproj(
            ("Watch App Debug", "watchos", "26.6"),
            ("NepalKitWatch Debug", "iphoneos", QUIET),
        )
        code, output = self._run(mixed, "26.6")
        self.assertEqual(code, 0, output)
        self.assertIn(f"project.pbxproj:{floor_lines(mixed, '26.6')[0]}", output,
                      "the watchos block must be reported")
        self.assertNotIn(QUIET, output, "the iOS-side container declares no watchOS floor")
        self.assertNotIn(f"project.pbxproj:{floor_lines(mixed, QUIET)[0]}", output,
                         "the container must not be named as a source")

    def test_every_disagreeing_watchos_block_is_named_not_just_the_first(self) -> None:
        three = watch_pbxproj(
            ("Watch App Debug", "watchos", "26.6"),
            ("NepalKitComplications Debug", "watchos", "26.0"),
            ("NepalKitWatchTests Debug", "watchos", "26.1"),
        )
        code, output = self._run(three, "26.6")
        self.assertEqual(code, 1)
        for value in ("26.6", "26.0", "26.1"):
            self.assertIn(value, output, f"{value} missing from the report")

    def test_the_gate_passes_with_no_built_product(self) -> None:
        code, output = self._run(PBXPROJ.replace("26.0", "26.6"), None)
        self.assertEqual(code, 0, output)
        self.assertNotIn("built product", output)


class RealRepositoryTests(unittest.TestCase):

    def test_the_repository_floor_is_consistent(self) -> None:
        captured = io.StringIO()
        with contextlib.redirect_stdout(captured):
            code = vdf.main()
        self.assertEqual(code, 0, captured.getvalue())

    def test_the_repository_project_format_is_one_the_floor_job_can_read(self) -> None:
        with contextlib.redirect_stdout(io.StringIO()):
            problem = vdf._project_format_problem(
                vdf.PROJECT.read_text(encoding="utf-8"))
        self.assertIsNone(problem, problem or "")

    def test_every_watchos_block_in_the_project_is_read_by_the_gate(self) -> None:
        text = vdf.PROJECT.read_text(encoding="utf-8")
        watchos_blocks = text.count("SDKROOT = watchos;")
        self.assertEqual(
            len(vdf.watchos_project_floors(text)), watchos_blocks,
            "every block declaring its own watchOS SDKROOT must be read as a floor",
        )

    def test_the_repository_watchos_floor_is_consistent(self) -> None:
        text = vdf.PROJECT.read_text(encoding="utf-8")
        values = {value for _, value in vdf.watchos_project_floors(text)}
        self.assertEqual(len(values), 1,
                         f"watchOS blocks disagree in the real project: {sorted(values)}")

    def test_the_repository_watchos_blocks_declare_26_0(self) -> None:
        values = {value for _, value in
                  vdf.watchos_project_floors(vdf.PROJECT.read_text(encoding="utf-8"))}
        self.assertEqual(values, {"26.0"},
                         "the watchOS product floor is 26.0, ratified by the user "
                         "after the d92dea8 interlude. If the floor is moving, "
                         "change every WATCHOS_DEPLOYMENT_TARGET in the project "
                         "and this value together - that is the fix this failure "
                         "is asking for, not a reason to doubt it")

    def test_the_appcast_verifier_reads_the_project_floor(self) -> None:
        floors = {value for _, value in vdf.project_floors(vdf.PROJECT.read_text(encoding="utf-8"))}
        self.assertEqual({xcode_project.macos_floor()}, floors)


if __name__ == "__main__":
    unittest.main()
