#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Dibas Sigdel
"""Tests for update-changelog.py.

Each test runs a copy of the script in a temporary replica of the repository,
so the real CHANGELOG.md is never touched.
"""

from __future__ import annotations

import importlib.util
import shutil
import subprocess
import sys
import tempfile
import unittest
from dataclasses import dataclass
from pathlib import Path

_SCRIPT = Path(__file__).resolve().parent / "update-changelog.py"
_spec = importlib.util.spec_from_file_location("update_changelog", _SCRIPT)
uc = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(uc)

REPO = _SCRIPT.parent.parent

NOTE = "<b>Notes:</b><ul><li>a fix</li></ul>"
# The offset form appcast.xml carries, for 2026-09-29 and 2026-09-30.
PUBLISHED_0929 = "Tue, 29 Sep 2026 01:04:35 +0545"
PUBLISHED_0930 = "Wed, 30 Sep 2026 10:00:00 +0545"


def feed(*releases: tuple[str, str]) -> str:
    """A minimal appcast carrying the given (version, pubDate) pairs."""
    items = "".join(
        "<item><title>t</title>"
        f"<pubDate>{published}</pubDate>"
        f"<sparkle:shortVersionString>{version}</sparkle:shortVersionString>"
        "</item>"
        for version, published in releases
    )
    return f'<?xml version="1.0"?><rss version="2.0"><channel>{items}</channel></rss>'


def changelog(*releases: tuple[str, str]) -> str:
    """A changelog whose headings already carry dates, as a shipped one does."""
    return "".join(f"## {version} — {date}\n\n{NOTE}\n\n" for version, date in releases)


def repo_notes() -> dict[str, str]:
    """The repository's real release-notes fragments, keyed by version."""
    return {
        path.stem: path.read_text(encoding="utf-8")
        for path in (_SCRIPT.parent / "release-notes").glob("*.html")
    }


@dataclass
class Sandbox:
    """A throwaway replica of the tree the generator resolves its paths from."""

    root: Path
    script: Path
    changelog: Path
    appcast: Path

    def run(self, *args: str) -> subprocess.CompletedProcess:
        return subprocess.run(
            [sys.executable, str(self.script), *args],
            capture_output=True,
            text=True,
        )


def make_sandbox(
    root: Path,
    *,
    changelog: str | None = None,
    appcast: str | None = None,
    notes: dict[str, str] | None = None,
) -> Sandbox:
    """Build a replica of the tree `update-changelog.py` resolves its paths from.

    The script roots every path at `Path(__file__).parent.parent`, so it is
    copied into the replica.
    """
    (root / "scripts").mkdir()
    script = root / "scripts" / _SCRIPT.name
    shutil.copy(_SCRIPT, script)
    if notes is not None:
        notes_dir = root / "scripts" / "release-notes"
        notes_dir.mkdir()
        for version, body in notes.items():
            (notes_dir / f"{version}.html").write_text(body, encoding="utf-8")
    box = Sandbox(
        root=root,
        script=script,
        changelog=root / "CHANGELOG.md",
        appcast=root / "appcast.xml",
    )
    if changelog is not None:
        box.changelog.write_text(changelog, encoding="utf-8")
    if appcast is not None:
        box.appcast.write_text(appcast, encoding="utf-8")
    return box


class MissingAppcastFails(unittest.TestCase):
    def test_named_appcast_that_does_not_exist_is_an_error(self) -> None:
        # A missing staged appcast must not mark every release as unreleased.
        with tempfile.TemporaryDirectory() as tmp:
            box = make_sandbox(Path(tmp), changelog=changelog(("1.1", "2026-09-29")))
            result = box.run(str(box.root / "absent.xml"))
        self.assertEqual(result.returncode, 1, result.stdout + result.stderr)
        self.assertIn("no appcast at", result.stderr)

    def test_a_failed_run_leaves_the_changelog_untouched(self) -> None:
        shipped = changelog(("1.1", "2026-09-29"))
        with tempfile.TemporaryDirectory() as tmp:
            box = make_sandbox(Path(tmp), changelog=shipped)
            box.run(str(box.root / "absent.xml"))
            self.assertEqual(box.changelog.read_text(encoding="utf-8"), shipped)

    def test_a_lone_flag_is_rejected_rather_than_treated_as_a_path(self) -> None:
        # "--help" is not a flag; it is rejected as a missing file.
        shipped = changelog(("1.1", "2026-09-29"))
        with tempfile.TemporaryDirectory() as tmp:
            box = make_sandbox(Path(tmp), changelog=shipped)
            result = box.run("--help")
            self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)
            self.assertIn("no appcast at --help", result.stderr)
            self.assertEqual(box.changelog.read_text(encoding="utf-8"), shipped)

    def test_extra_arguments_are_a_usage_error(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            box = make_sandbox(Path(tmp), changelog=changelog(("1.1", "2026-09-29")))
            result = box.run("first.xml", "second.xml")
        self.assertEqual(result.returncode, 2, result.stdout + result.stderr)
        self.assertIn("usage:", result.stderr)


class RenderingStaysDeterministic(unittest.TestCase):
    def test_a_version_without_an_appcast_item_is_listed_unreleased(self) -> None:
        # 1.2 has notes but no appcast item yet, so it is unreleased.
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
        # Regenerating from the real inputs changes nothing. 1.0's date is only
        # in the changelog, so this also checks that changelog dates are kept.
        shipped = (REPO / "CHANGELOG.md").read_text(encoding="utf-8")
        with tempfile.TemporaryDirectory() as tmp:
            box = make_sandbox(
                Path(tmp),
                changelog=shipped,
                appcast=(REPO / "appcast.xml").read_text(encoding="utf-8"),
                notes=repo_notes(),
            )
            result = box.run()
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            self.assertEqual(box.changelog.read_text(encoding="utf-8"), shipped)


class DatePrecedence(unittest.TestCase):
    """Which source wins when one version's date is written in several places."""

    def _resolve(
        self,
        root: Path,
        committed: str,
        staged: str,
        written: tuple[tuple[str, str], ...],
    ) -> dict[str, str]:
        box = make_sandbox(root, changelog=changelog(*written), appcast=committed)
        staged_path = root / "staged.xml"
        staged_path.write_text(staged, encoding="utf-8")
        return uc.resolve_dates(box.appcast, staged_path, box.changelog)

    def test_a_written_date_outranks_a_staged_feed_that_disagrees(self) -> None:
        # A staged pubDate must not overwrite a date already in the changelog.
        with tempfile.TemporaryDirectory() as tmp:
            dates = self._resolve(
                Path(tmp),
                committed=feed(("1.1", PUBLISHED_0929)),
                staged=feed(("1.1", PUBLISHED_0930)),
                written=(("1.1", "2026-09-29"),),
            )
        self.assertEqual(
            dates,
            {"1.1": "2026-09-29"},
            "a date already written to the changelog must outrank a staged "
            "feed that disagrees with it",
        )

    def test_a_version_the_changelog_has_never_dated_takes_the_feed(self) -> None:
        # 1.3.0 has no heading yet, so its date comes from the feed.
        with tempfile.TemporaryDirectory() as tmp:
            dates = self._resolve(
                Path(tmp),
                committed=feed(("1.2", PUBLISHED_0929)),
                staged=feed(("1.3.0", PUBLISHED_0930)),
                written=(("1.2", "2026-09-29"),),
            )
        self.assertEqual(dates, {"1.2": "2026-09-29", "1.3.0": "2026-09-30"})

    def test_a_release_the_pruned_feed_forgot_keeps_its_written_date(self) -> None:
        # generate_appcast prunes old items, so these dates survive only via the changelog.
        with tempfile.TemporaryDirectory() as tmp:
            dates = self._resolve(
                Path(tmp),
                committed=feed(("1.3.0", PUBLISHED_0930)),
                staged=feed(("1.3.0", PUBLISHED_0930)),
                written=(
                    ("1.3.0", "2026-09-30"),
                    ("1.2", "2026-09-29"),
                    ("1.1", "2026-09-29"),
                    ("1.0", "2026-09-28"),
                ),
            )
        self.assertEqual(
            dates,
            {
                "1.3.0": "2026-09-30",
                "1.2": "2026-09-29",
                "1.1": "2026-09-29",
                "1.0": "2026-09-28",
            },
        )


if __name__ == "__main__":
    unittest.main()
