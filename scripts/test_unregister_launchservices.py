#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Dibas Sigdel
"""Tests for `unregister-launchservices.sh`.

The script's job is to prevent a permanent, invisible failure: a bundle
registered with LaunchServices whose path is later deleted cannot be
unregistered, so a pipeline that cleans up without unregistering first seeds
one stale entry per run forever. A test that only confirmed the happy path
would pass against a script that never unregistered anything, because
`lsregister -u` on a path with no registration is also a clean no-op.

So the fixtures here register real throwaway bundles under unique bundle ids,
and the assertions are about the database afterwards. They also drive the
mistake the script exists to catch — deleting before unregistering — and
require that the script *report* it rather than pass.
"""

from __future__ import annotations

import subprocess
import tempfile
import time
import unittest
import uuid
from pathlib import Path

SCRIPT = Path(__file__).resolve().parent / "unregister-launchservices.sh"
LSREGISTER = (
    "/System/Library/Frameworks/CoreServices.framework/Frameworks"
    "/LaunchServices.framework/Support/lsregister"
)

PLIST = """<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleIdentifier</key><string>{bundle_id}</string>
<key>CFBundleName</key><string>{name}</string>
<key>CFBundleExecutable</key><string>{name}</string>
<key>CFBundlePackageType</key><string>APPL</string>
</dict></plist>
"""


def run(*args: str) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        [str(SCRIPT), *args], capture_output=True, text=True
    )


def registered(path: str) -> bool:
    """Whether any LaunchServices registration names this path.

    Both the given path and its resolved form are checked, because the
    database records resolved paths while a caller on macOS passes
    `/var/folders/...` and LaunchServices stores `/private/var/folders/...`.
    Checking only one of the two makes a surviving registration read as a
    clean run.
    """
    candidates = {path, str(Path(path).resolve())}
    dump = subprocess.run(
        [LSREGISTER, "-dump"], capture_output=True, text=True
    ).stdout
    for line in dump.splitlines():
        stripped = line.strip()
        if not stripped.startswith("path:"):
            continue
        value = stripped[len("path:") :].strip().split(" (0x")[0]
        for candidate in candidates:
            if value == candidate or value.startswith(candidate + "/"):
                return True
    return False


class UnregisterLaunchServices(unittest.TestCase):
    """Drives the real `lsregister` against throwaway bundles."""

    def setUp(self) -> None:
        self.workspace = Path(tempfile.mkdtemp(prefix="nk-ls-test."))
        self.addCleanup(self._remove_workspace)
        self._bundle_ids: list[str] = []

    def _remove_workspace(self) -> None:
        # Unregister before deleting, which is the ordering the script
        # documents; leaving entries behind would make the next run of this
        # suite the thing it is testing for.
        for bundle in self.workspace.glob("*.app"):
            if bundle.exists():
                subprocess.run(
                    [LSREGISTER, "-u", str(bundle)],
                    capture_output=True,
                    text=True,
                )
        subprocess.run(["rm", "-rf", str(self.workspace)], check=False)

    def make_bundle(self, name: str, *, register: bool = True) -> Path:
        bundle = self.workspace / name
        (bundle / "Contents" / "MacOS").mkdir(parents=True)
        bundle_id = f"com.dibas.NepalKitTests.LsProbe{uuid.uuid4().hex[:8]}"
        self._bundle_ids.append(bundle_id)
        (bundle / "Contents" / "Info.plist").write_text(
            PLIST.format(bundle_id=bundle_id, name=name.split(".")[0])
        )
        if register:
            subprocess.run([LSREGISTER, "-f", str(bundle)], check=True)
            # Registration is asynchronous: `lsregister` returns before the
            # database dump reflects it, so a fixture asserted too early reads
            # as "never registered" and the test would fail on a machine that
            # is merely slower than this one.
            for _ in range(20):
                if self._bundle_id_registered(self._bundle_ids[-1]):
                    break
                time.sleep(0.25)
        return bundle

    def test_a_registered_bundle_is_unregistered(self) -> None:
        bundle = self.make_bundle("Live.app")
        self.assertTrue(
            registered(str(bundle)), "the fixture did not register; nothing is being proved"
        )

        result = run(str(bundle))

        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertFalse(registered(str(bundle)), "the registration survived")
        self.assertIn("unregistered:", result.stdout)

    def test_a_bundle_that_was_never_registered_is_not_an_error(self) -> None:
        # Nothing to prove is not a failure: a run that only builds some of
        # the bundles should not fail on the ones it did not build.
        bundle = self.make_bundle("Never.app", register=False)

        result = run(str(bundle))

        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def test_a_deleted_bundle_is_reported_rather_than_passed(self) -> None:
        # The failure this whole script exists to prevent, asked about
        # directly: the bundle is already gone, so `lsregister -u` cannot
        # remove its entry, and the only honest answer is failure.
        bundle = self.make_bundle("Gone.app")
        bundle_id = self._bundle_ids[0]
        subprocess.run(["rm", "-rf", str(bundle)], check=True)

        result = run(str(bundle))

        self.assertEqual(result.returncode, 1)
        self.assertIn("already gone", result.stderr)
        # Named, not just failed: the operator needs to know which path.
        self.assertIn(str(bundle), result.stderr)
        self.assertTrue(
            self._bundle_id_registered(bundle_id),
            "the fixture must still be registered, or this test proves nothing",
        )

    def test_several_bundles_are_all_handled_in_one_call(self) -> None:
        first = self.make_bundle("First.app")
        second = self.make_bundle("Second.app")
        second_id = self._bundle_ids[1]

        result = run(str(first), str(second))

        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertFalse(registered(str(first)))
        self.assertFalse(registered(str(second)))
        self.assertFalse(self._bundle_id_registered(second_id))

    def test_one_unremovable_bundle_does_not_hide_the_others(self) -> None:
        # A deleted path among live ones must not stop the live ones being
        # cleaned up, or a single early exit would leave the rest registered.
        live = self.make_bundle("Live.app")
        missing = self.workspace / "Missing.app"

        result = run(str(missing), str(live))

        self.assertEqual(result.returncode, 1)
        self.assertFalse(
            registered(str(live)), "the live bundle was skipped after the missing one"
        )

    def test_no_arguments_is_a_usage_error(self) -> None:
        result = run()

        self.assertEqual(result.returncode, 2)
        self.assertIn("usage:", result.stderr)

    def _bundle_id_registered(self, bundle_id: str) -> bool:
        dump = subprocess.run(
            [LSREGISTER, "-dump"], capture_output=True, text=True
        ).stdout
        return bundle_id in dump


if __name__ == "__main__":
    unittest.main()