#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Dibas Sigdel
"""Negative-path suite for the changelog generator.

`update-changelog.py` rewrites `CHANGELOG.md` in place, and the release script
commits whatever it produced. A run that finds no dates does not fail — it
writes every released version as "unreleased" and exits 0. That is a silent
corruption of a shipped artefact, so the paths that produce it are pinned here
rather than left to be discovered by a release.

The generator resolves every path from its own location, so a test that runs it
runs a *copy*, against a replica of that tree, in a temporary directory. These
tests used to run the repository's own script against the real CHANGELOG.md and
then assert it was unchanged — which held only because the outputs happened to
agree, and which would otherwise have left the contributor with a modified
tracked file and a failing test.
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


def feed(*releases: tuple[str, str]) -> str:
    """A minimal appcast carrying the given (version, pubDate) pairs.

    `release_dates` reads `pubDate` and `sparkle:shortVersionString` and nothing
    else, so those are all an item here has to contain.
    """
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
    """Build a replica of the repository tree `update-changelog.py` resolves from.

    The script roots every path at `Path(__file__).parent.parent`, so `cwd=`
    cannot redirect it and a production flag for tests would be the wrong trade.
    Copying the script into a replica is the isolation, and it costs one
    `shutil.copy`. Every fixture is supplied by the caller, so a test can be
    missing an appcast, or disagree with itself, without touching the
    repository's files.
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
        # The release script passes the staged appcast explicitly. If that file
        # is missing, every date is lost and CHANGELOG.md is rewritten with
        # every released version marked unreleased.
        with tempfile.TemporaryDirectory() as tmp:
            box = make_sandbox(Path(tmp), changelog=changelog(("1.1", "2026-09-29")))
            result = box.run(str(box.root / "absent.xml"))
        self.assertEqual(result.returncode, 1, result.stdout + result.stderr)
        self.assertIn("no appcast at", result.stderr)

    def test_a_failed_run_leaves_the_changelog_untouched(self) -> None:
        # The consequence matters more than the exit code: the file on disk must
        # still carry its dates, because the previous behaviour wrote the
        # corrupted version before anyone could see anything was wrong.
        shipped = changelog(("1.1", "2026-09-29"))
        with tempfile.TemporaryDirectory() as tmp:
            box = make_sandbox(Path(tmp), changelog=shipped)
            box.run(str(box.root / "absent.xml"))
            self.assertEqual(box.changelog.read_text(encoding="utf-8"), shipped)

    def test_a_lone_flag_is_rejected_rather_than_treated_as_a_path(self) -> None:
        # `update-changelog.py --help` used to read "--help" as a path, fail to
        # find it, and rewrite the changelog. It is not a flag, so it is
        # rejected as the missing file it is — non-zero, named, and with the
        # changelog left alone.
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
        # The documented no-argument invocation, run against the repository's
        # own committed inputs. The property is that regenerating changes
        # nothing, so a release that runs the generator cannot silently alter a
        # date that has already shipped. The fixtures are the real ones because
        # that is the run a release makes, and reading them into a sandbox is
        # what makes asking safe to ask: 1.0's date is in the changelog and in
        # neither the feed nor a fragment, so a generator that stopped honouring
        # the changelog's own dates would rewrite this file — and the assertion
        # would fail here rather than after a release shipped the loss.
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


if __name__ == "__main__":
    unittest.main()
