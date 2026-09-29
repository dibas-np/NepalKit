#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Dibas Sigdel
"""Negative-path suite for the changelog generator.

`update-changelog.py` rewrites `CHANGELOG.md` in place, and the release script
commits whatever it produced. A run that finds no dates does not fail — it
writes every released version as "unreleased" and exits 0. That is a silent
corruption of a shipped artefact, so the paths that produce it are pinned here
rather than left to be discovered by a release.
"""

from __future__ import annotations

import importlib.util
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

_SCRIPT = Path(__file__).resolve().parent / "update-changelog.py"
_spec = importlib.util.spec_from_file_location("update_changelog", _SCRIPT)
uc = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(uc)

REPO = _SCRIPT.parent.parent


class MissingAppcastFails(unittest.TestCase):
    def _run(self, *args: str) -> subprocess.CompletedProcess:
        return subprocess.run(
            [sys.executable, str(_SCRIPT), *args],
            capture_output=True,
            text=True,
        )

    def test_named_appcast_that_does_not_exist_is_an_error(self) -> None:
        # The release script passes the staged appcast explicitly. If that file
        # is missing, every date is lost and CHANGELOG.md is rewritten with
        # every released version marked unreleased.
        with tempfile.TemporaryDirectory() as tmp:
            result = self._run(str(Path(tmp) / "absent.xml"))
        self.assertEqual(result.returncode, 1, result.stdout + result.stderr)
        self.assertIn("no appcast at", result.stderr)

    def test_a_failed_run_leaves_the_changelog_untouched(self) -> None:
        # The consequence matters more than the exit code: the file on disk must
        # still carry its dates, because the previous behaviour wrote the
        # corrupted version before anyone could see anything was wrong.
        before = (REPO / "CHANGELOG.md").read_text(encoding="utf-8")
        with tempfile.TemporaryDirectory() as tmp:
            self._run(str(Path(tmp) / "absent.xml"))
        self.assertEqual(
            (REPO / "CHANGELOG.md").read_text(encoding="utf-8"), before
        )

    def test_a_lone_flag_is_rejected_rather_than_treated_as_a_path(self) -> None:
        # `update-changelog.py --help` used to read "--help" as a path, fail to
        # find it, and rewrite the changelog. It is not a flag, so it is
        # rejected as the missing file it is — non-zero, named, and with the
        # changelog left alone.
        before = (REPO / "CHANGELOG.md").read_text(encoding="utf-8")
        result = self._run("--help")
        self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn("no appcast at --help", result.stderr)
        self.assertEqual(
            (REPO / "CHANGELOG.md").read_text(encoding="utf-8"), before
        )

    def test_extra_arguments_are_a_usage_error(self) -> None:
        result = self._run("first.xml", "second.xml")
        self.assertEqual(result.returncode, 2, result.stdout + result.stderr)
        self.assertIn("usage:", result.stderr)


class RenderingStaysDeterministic(unittest.TestCase):
    def test_a_version_without_an_appcast_item_is_listed_unreleased(self) -> None:
        # The legitimate case the guard must not break: 1.2 has notes but no
        # appcast item yet, and that is what "unreleased" is for.
        with tempfile.NamedTemporaryFile(suffix=".xml") as appcast:
            appcast.write(
                b'<?xml version="1.0"?><rss version="2.0"><channel><item>'
                b"<title>1.1</title>"
                b"<pubDate>Tue, 29 Sep 2026 01:04:35 +0545</pubDate>"
                b"<sparkle:shortVersionString>1.1</sparkle:shortVersionString>"
                b"</item></channel></rss>"
            )
            appcast.flush()
            self.assertEqual(
                uc.release_dates(Path(appcast.name)), {"1.1": "2026-09-29"}
            )

    def test_running_with_no_arguments_rewrites_nothing(self) -> None:
        # The documented invocation, and the one CI checks for determinism.
        before = (REPO / "CHANGELOG.md").read_text(encoding="utf-8")
        result = subprocess.run(
            [sys.executable, str(_SCRIPT)], capture_output=True, text=True
        )
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual(
            (REPO / "CHANGELOG.md").read_text(encoding="utf-8"), before
        )


if __name__ == "__main__":
    unittest.main()
