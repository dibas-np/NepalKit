#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Dibas Sigdel
"""Tests for `verify-deployment-floor.py`."""

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
PACKAGE_SW = (
    "// swift-tools-version: 6.2\n"
    "import PackageDescription\n"
    "\n"
    "let package = Package(\n"
    "    name: \"NepalKitCore\",\n"
    "    platforms: [.macOS(.v26), .watchOS(.v26)],\n"
    "    targets: [\n"
    "        .target(name: \"NepalKitCore\"),\n"
    "    ]\n"
    ")\n"
)

# A watchOS floor used in no other fixture block, so its absence is checkable.
QUIET = "26.9"


def watch_pbxproj(*blocks: tuple[str, str | None, str]) -> str:
    """A project file whose blocks are exactly ``blocks``.

    Each block is ``(name, sdkroot, floor)``; ``sdkroot`` of ``None`` inherits
    SDKROOT from the project level, like the macOS app target.
    """
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
    """Line numbers of every ``WATCHOS_DEPLOYMENT_TARGET = <value>;`` in ``text``."""
    needle = f"WATCHOS_DEPLOYMENT_TARGET = {value};"
    return [n for n, line in enumerate(text.splitlines(), start=1) if needle in line]


# The block shapes in the real project: two watchOS blocks, the macOS app
# target (inherits macosx) and the iOS-side watch container.
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
        # An absent key means "inherit", not a floor.
        no_key = PBXPROJ.replace("\t\t\t\tMACOSX_DEPLOYMENT_TARGET = 26.6;\n", "")
        remaining = vdf.project_floors(no_key)
        self.assertEqual([value for _, value in remaining], ["26.0"],
                         "only the block that still declares a floor is reported")


class WatchOSProjectFloorParsingTests(unittest.TestCase):
    """Only blocks with their own ``SDKROOT = watchos`` declare a watchOS floor."""

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
        # Like the macOS app target, which inherits macosx but carries the key.
        only_inherited = watch_pbxproj(("NepalKit Mac App Debug", None, QUIET))
        self.assertEqual(vdf.watchos_project_floors(only_inherited), [],
                         "no SDKROOT of its own means no watchOS floor")

    def test_the_watch_container_does_not_declare_a_watchos_floor(self) -> None:
        # The iOS-side watch container.
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


class PackageManifestFloorParsingTests(unittest.TestCase):
    """``.watchOS(...)`` out of NepalKitCore/Package.swift's platforms list."""

    def test_reads_the_declared_platform(self) -> None:
        line, value = vdf.package_watchos_floor(PACKAGE_SW)
        self.assertEqual(value, "26")
        self.assertIn(".watchOS(.v26)", PACKAGE_SW.splitlines()[line - 1])

    def test_a_manifest_with_no_watchos_platform_is_absent_not_a_default(self) -> None:
        without = PACKAGE_SW.replace(".watchOS(.v26)", "")
        self.assertIsNone(vdf.package_watchos_floor(without),
                          "no .watchOS platform must read as absent, not as a version")

    def test_a_platform_inside_a_comment_is_not_the_declaration(self) -> None:
        commented = "// was once: platforms: [.watchOS(.v27)]\n" + PACKAGE_SW
        line, value = vdf.package_watchos_floor(commented)
        self.assertEqual(value, "26", "the commented-out platform must not be read")
        self.assertEqual(commented.splitlines()[line - 1].strip(),
                         "platforms: [.macOS(.v26), .watchOS(.v26)],")

    def test_the_macos_platform_is_not_mistaken_for_the_watchos_one(self) -> None:
        line, value = vdf.package_watchos_floor(PACKAGE_SW)
        self.assertIn(".watchOS", PACKAGE_SW.splitlines()[line - 1],
                      "the line reported must be the one declaring .watchOS")


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
        # plistlib returns the unexpanded token too; the comparison must reject it.
        self.assertEqual(vdf.product_floor(self._plist("$(MACOSX_DEPLOYMENT_TARGET)")),
                         "$(MACOSX_DEPLOYMENT_TARGET)")

    def test_a_product_with_no_floor_key_reads_as_absent_not_as_empty(self) -> None:
        self.assertIsNone(vdf.product_floor(self._plist(None)))

    def test_an_unreadable_path_is_absent_not_an_error(self) -> None:
        self.assertIsNone(vdf.product_floor(Path("/nonexistent/Info.plist")))


class GateHarness:
    """Points the module's path constants at temp files and restores them."""

    def _run(self, project: str, release: str, built: str | None,
             package: str = PACKAGE_SW) -> tuple[int, str]:
        captured = io.StringIO()
        code = 0
        with contextlib.redirect_stdout(captured):
            with self._patch_sources(project, release, built, package):
                code = vdf.main()
        return code, captured.getvalue()

    @contextlib.contextmanager
    def _patch_sources(self, project: str, release: str, built: str | None,
                       package: str = PACKAGE_SW):
        original_project, original_release = vdf.PROJECT, vdf.RELEASE_SCRIPT
        had_package = hasattr(vdf, "PACKAGE")
        original_package = getattr(vdf, "PACKAGE", None)
        original_locate = vdf._locate_built_product
        original_plist = vdf.product_floor
        project_path = Path(tempfile.mkdtemp()) / "project.pbxproj"
        project_path.write_text(project, encoding="utf-8")
        release_path = Path(tempfile.mkdtemp()) / "package-release.sh"
        release_path.write_text(release, encoding="utf-8")
        package_path = Path(tempfile.mkdtemp()) / "Package.swift"
        package_path.write_text(package, encoding="utf-8")
        vdf.PROJECT, vdf.RELEASE_SCRIPT = project_path, release_path
        vdf.PACKAGE = package_path
        # Patch both, or the built-product path is never exercised.
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
            if had_package:
                vdf.PACKAGE = original_package
            else:
                del vdf.PACKAGE
            vdf._locate_built_product = original_locate
            vdf.product_floor = original_plist

class DriftDetectionTests(GateHarness, unittest.TestCase):
    """One source out of step must give a non-zero exit."""

    def test_all_sources_agreeing_passes(self) -> None:
        code, output = self._run(PBXPROJ.replace("26.0", "26.6"), RELEASE_SH, "26.6")
        self.assertEqual(code, 0, output)
        self.assertIn("everywhere it is written", output)

    def test_a_project_level_config_behind_the_app_target_fails(self) -> None:
        code, output = self._run(PBXPROJ, RELEASE_SH, "26.6")
        self.assertEqual(code, 1, "a project-level config behind the target must fail")
        self.assertIn("NOT consistent", output)

    def test_the_release_script_behind_the_project_fails(self) -> None:
        code, output = self._run(
            PBXPROJ.replace("26.0", "26.6"), "DEPLOYMENT_TARGET=26.0\n", "26.6"
        )
        self.assertEqual(code, 1, "verify-appcast.py trusts this file; it must agree")

    def test_a_built_product_behind_both_sources_fails(self) -> None:
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
        code, output = self._run(PBXPROJ.replace("26.0", "26.6"), "#!/bin/sh\nARCHIVE=x\n", None)
        self.assertNotEqual(code, 0)
        self.assertIn("DEPLOYMENT_TARGET", output)

    def test_the_format_xcode_27_writes_is_the_one_ci_can_read(self) -> None:
        # Xcode 27 writes 110, so the ceiling must accept it.
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
        # Make sure the probe is actually parsed, so the assertIsNone tests mean something.
        self.assertEqual(
            vdf._project_format_problem("\tobjectVersion = 111;\n") is not None,
            True,
            "if this fails, every version test above is passing vacuously",
        )

    def test_a_project_with_no_object_version_is_not_a_failure(self) -> None:
        self.assertIsNone(vdf._project_format_problem("{ objects = 1; }\n"))

    def test_watchos_blocks_that_disagree_fail_and_name_both(self) -> None:
        code, output = self._run(THREE_SHAPES, RELEASE_SH, "26.6")
        self.assertEqual(code, 1, "two watchOS blocks at different floors must fail")
        for value in ("26.6", "26.0"):
            self.assertIn(value, output, f"{value} missing from the report")

    def test_all_watchos_blocks_agreeing_passes(self) -> None:
        agreeing = watch_pbxproj(
            ("Watch App Debug", "watchos", "26.6"),
            ("NepalKitComplications Debug", "watchos", "26.6"),
        )
        code, output = self._run(agreeing, RELEASE_SH, "26.6")
        self.assertEqual(code, 0, output)
        for line in floor_lines(agreeing, "26.6"):
            self.assertIn(f"project.pbxproj:{line}", output,
                          "an agreeing watchOS block must still be reported")

    def test_a_package_floor_above_the_app_exits_one(self) -> None:
        # The package may be at or below the app's floor, never above it.
        agreeing = watch_pbxproj(("Watch App Debug", "watchos", "26.6"))
        higher = PACKAGE_SW.replace(".watchOS(.v26)", ".watchOS(.v27)")
        code, output = self._run(agreeing, RELEASE_SH, "26.6", package=higher)
        self.assertEqual(code, 1, "a package floor above the app's must fail")
        self.assertIn("Package.swift:6", output,
                      "the message must name the line to edit")
        self.assertIn("higher than the 26.6", output,
                      "the message must say which way the two floors disagree")

    def test_the_package_floor_failure_does_not_claim_the_appcast_would_lie(self) -> None:
        # appcast.xml is the Mac app's feed, so the message must not mention it.
        agreeing = watch_pbxproj(("Watch App Debug", "watchos", "26.6"))
        higher = PACKAGE_SW.replace(".watchOS(.v26)", ".watchOS(.v27)")
        _code, output = self._run(agreeing, RELEASE_SH, "26.6", package=higher)
        self.assertNotIn("appcast", output.lower(),
                         "the appcast says nothing about watches, so this message "
                         "must not claim it does")
        self.assertIn("availability", output,
                      "the stated consequence must be the availability one")
        self.assertIn("fails on an older watch", output,
                      "the stated consequence must say where it surfaces")

    def test_a_package_floor_below_the_app_exits_zero(self) -> None:
        agreeing = watch_pbxproj(("Watch App Debug", "watchos", "26.6"))
        code, output = self._run(agreeing, RELEASE_SH, "26.6", package=PACKAGE_SW)
        self.assertEqual(code, 0, output)
        self.assertIn(f"project.pbxproj:{floor_lines(agreeing, '26.6')[0]}", output)
        self.assertIn("26", output)

    def test_a_stale_watchos_key_on_an_inherited_sdkroot_block_is_silent(self) -> None:
        mixed = watch_pbxproj(
            ("Watch App Debug", "watchos", "26.6"),
            ("NepalKit Mac App Debug", None, QUIET),
        )
        code, output = self._run(mixed, RELEASE_SH, "26.6")
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
        code, output = self._run(mixed, RELEASE_SH, "26.6")
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
        code, output = self._run(three, RELEASE_SH, "26.6")
        self.assertEqual(code, 1)
        for value in ("26.6", "26.0", "26.1"):
            self.assertIn(value, output, f"{value} missing from the report")

    def test_the_gate_passes_with_no_built_product(self) -> None:
        code, output = self._run(PBXPROJ.replace("26.0", "26.6"), RELEASE_SH, None)
        self.assertEqual(code, 0, output)
        self.assertNotIn("built product", output)


class RealRepositoryTests(unittest.TestCase):

    def test_the_repository_floor_is_consistent(self) -> None:
        captured = io.StringIO()
        with contextlib.redirect_stdout(captured):
            code = vdf.main()
        self.assertEqual(code, 0, captured.getvalue())

    def test_the_repository_project_format_is_one_the_floor_job_can_read(self) -> None:
        # ADR-0007: Xcode 26 cannot open an objectVersion 110 project.
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
        # The tests are the one place a watchOS version is hard-coded. Update it
        # together with every WATCHOS_DEPLOYMENT_TARGET in the project.
        values = {value for _, value in
                  vdf.watchos_project_floors(vdf.PROJECT.read_text(encoding="utf-8"))}
        self.assertEqual(values, {"26.0"},
                         "the watchOS product floor is 26.0, ratified by the user "
                         "after the d92dea8 interlude. If the floor is moving, "
                         "change every WATCHOS_DEPLOYMENT_TARGET in the project "
                         "and this value together - that is the fix this failure "
                         "is asking for, not a reason to doubt it")

    def test_the_package_floor_is_not_above_the_app(self) -> None:
        text = vdf.PROJECT.read_text(encoding="utf-8")
        values = {value for _, value in vdf.watchos_project_floors(text)}
        self.assertEqual(len(values), 1, "the watchOS floor must be one value first")
        package = vdf.package_watchos_floor(vdf.PACKAGE.read_text(encoding="utf-8"))
        self.assertIsNotNone(package, "NepalKitCore must still declare a watchOS platform")
        assert package is not None
        app_floor = values.pop()
        self.assertLessEqual(
            vdf._version(package[1]), vdf._version(app_floor),
            f"Package.swift declares watchOS {package[1]} but the app declares "
            f"{app_floor}; the package must not require more than its consumer",
        )

    def test_the_release_script_floor_is_what_the_verifier_reads(self) -> None:
        # verify-appcast.py must read its floor from the file this gate checks.
        verifier = (vdf.REPO_ROOT / "scripts" / "verify-appcast.py").read_text(encoding="utf-8")
        self.assertIn("package-release.sh", verifier)
        self.assertIn("DEPLOYMENT_TARGET", verifier)


if __name__ == "__main__":
    unittest.main()
