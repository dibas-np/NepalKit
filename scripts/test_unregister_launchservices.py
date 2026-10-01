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

import re
import shutil
import subprocess
import tempfile
import time
import unittest
import uuid
from pathlib import Path
from unittest.mock import patch

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
        [LSREGISTER, "-dump"], capture_output=True, text=True, check=True
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
        for bundle_id in self._bundle_ids:
            self.assertFalse(self._bundle_id_registered(bundle_id), "fixture registration survived cleanup")
        shutil.rmtree(self.workspace)

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
        backup = self.workspace / "deleted-bundle-backup"
        shutil.copytree(bundle, backup)
        self.addCleanup(shutil.copytree, backup, bundle, dirs_exist_ok=True)
        shutil.rmtree(bundle)

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
            [LSREGISTER, "-dump"], capture_output=True, text=True, check=True
        ).stdout
        return bundle_id in dump


class PackageReleaseWiring(unittest.TestCase):
    """The release script's unregistration gate must be able to fail.

    package-release.sh wraps unregistration in a function so the EXIT trap
    can never abort the unmounts beneath it. That same function is the last
    gate of a successful run, and there a swallowed failure is a false green:
    a stale registration — the exact thing unregister-launchservices.sh
    exists to prevent — would ship with the release reporting success.
    """

    def function_body(self, name: str = "unregister_launchservices") -> str:
        source = (Path(__file__).resolve().parent / "package-release.sh").read_text()
        match = re.search(
            rf"^{name}\(\) \{{\n(.*?)^\}}", source, re.S | re.M
        )
        self.assertIsNotNone(
            match, f"{name}() not found in package-release.sh"
        )
        return match.group(1)

    def test_the_function_propagates_failure(self) -> None:
        body = self.function_body()
        self.assertNotIn(
            "|| true", body,
            "the release gate's unregistration swallows the failure it reports",
        )
        self.assertNotIn(
            "return 0", body, "a constant success return is the dead gate"
        )
        self.assertRegex(body, r'return "\$\{?unregister_result')

    def test_the_helper_is_resolved_from_root_in_an_unrelated_directory(self) -> None:
        harness = (
            "set -euo pipefail\n"
            "unregister_launchservices() {\n"
            + self.function_body()
            + "}\nunregister_launchservices\n"
        )
        with tempfile.TemporaryDirectory(prefix="nk release wiring ") as directory:
            workspace = Path(directory)
            root = workspace / "fake repository"
            scripts = root / "scripts"
            scripts.mkdir(parents=True)
            stub = scripts / "unregister-launchservices.sh"
            stub.write_text(
                '#!/bin/zsh\n'
                'printf "%s\\n" "$1" >> "$NK_TEST_LOG"\n'
                'exit "$NK_TEST_EXIT"\n'
            )
            stub.chmod(0o755)
            bundle = workspace / "Built app.app"
            bundle.mkdir()
            unrelated = workspace / "unrelated directory"
            unrelated.mkdir()
            for exit_code in (0, 1):
                with self.subTest(exit_code=exit_code):
                    log = workspace / f"invocation {exit_code}.log"
                    result = subprocess.run(
                        ["/bin/zsh", "-c", harness],
                        cwd=unrelated,
                        env={
                            "ROOT": str(root),
                            "APP": "NepalKit",
                            "APP_PATH": str(bundle),
                            "DMG_LAYOUT_MOUNT": str(workspace / "missing layout"),
                            "MNT": str(workspace / "missing mount"),
                            "WORK": str(workspace / "missing work"),
                            "NK_TEST_LOG": str(log),
                            "NK_TEST_EXIT": str(exit_code),
                        },
                        capture_output=True,
                        text=True,
                    )
                    self.assertEqual(
                        result.returncode, exit_code, result.stdout + result.stderr
                    )
                    self.assertTrue(
                        log.exists(), "the helper must run even when it reports failure"
                    )
                    self.assertEqual(log.read_text().splitlines(), [str(bundle)])

    def test_cleanup_retains_workspace_after_failure_and_repeated_traps(self) -> None:
        body = self.function_body("cleanup")
        for fail_first in (False, True):
            with self.subTest(fail_first=fail_first), tempfile.TemporaryDirectory() as directory:
                workspace = Path(directory) / "release workspace"
                workspace.mkdir()
                log = Path(directory) / "unmounts.log"
                harness = (
                    "set -euo pipefail\n"
                    "LS_CLEANUP_FAILED=0\nAPP_PATH=/test/export/NepalKit.app\n"
                    "calls=0\n"
                    "unregister_launchservices() { (( calls += 1 )); "
                    + ("[[ $calls -gt 1 ]];" if fail_first else "return 0;")
                    + " }\n"
                    'diskutil() { printf "%s\\n" "$*" >> "$NK_TEST_LOG"; }\n'
                    "cleanup() {\n" + body + "}\ncleanup\ncleanup\n"
                )
                result = subprocess.run(
                    ["/bin/zsh", "-c", harness],
                    env={"WORK": str(workspace), "MNT": "/test/check", "DMG_LAYOUT_MOUNT": "/test/layout",
                         "DMG_LAYOUT_DEVICE": "/dev/test", "NK_TEST_LOG": str(log)},
                    capture_output=True, text=True,
                )
                self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
                self.assertEqual(workspace.exists(), fail_first)
                self.assertEqual(len(log.read_text().splitlines()), 6)
                if fail_first:
                    self.assertIn(str(workspace), result.stderr)

    def test_final_gate_fails_and_retains_workspace_even_if_cleanup_retry_succeeds(self) -> None:
        source = (SCRIPT.parent / "package-release.sh").read_text()
        gate = source[source.rindex("unregister_launchservices || {"):]
        with tempfile.TemporaryDirectory() as directory:
            workspace = Path(directory) / "release workspace"
            workspace.mkdir()
            harness = (
                "set -euo pipefail\nLS_CLEANUP_FAILED=0\ncalls=0\n"
                "unregister_launchservices() { (( calls += 1 )); [[ $calls -gt 1 ]]; }\n"
                "diskutil() { return 0; }\n"
                "cleanup() {\n" + self.function_body("cleanup") + "}\n"
                "trap cleanup EXIT\n" + gate
            )
            result = subprocess.run(
                ["/bin/zsh", "-c", harness],
                env={"WORK": str(workspace), "APP_PATH": str(workspace / "NepalKit.app"),
                     "MNT": "/test/check", "DMG_LAYOUT_MOUNT": "/test/layout", "DMG_LAYOUT_DEVICE": ""},
                capture_output=True, text=True,
            )
            self.assertEqual(result.returncode, 1, result.stdout + result.stderr)
            self.assertTrue(workspace.exists(), "the final gate's failed registration must remain recoverable")
            self.assertIn("release hygiene failed", result.stderr)
            self.assertIn(str(workspace / "NepalKit.app"), result.stderr)

    def test_mount_paths_and_finder_disk_names_are_unique_per_release(self) -> None:
        source = (SCRIPT.parent / "package-release.sh").read_text()
        assignments = "\n".join(re.findall(r"^(?:DMG_LAYOUT_MOUNT|MNT)=.*$", source, re.M))
        mounts = []
        for work in ("/tmp/NepalKit-release.first", "/tmp/NepalKit-release.second"):
            result = subprocess.run(
                ["/bin/zsh", "-c", 'APP=NepalKit\nWORK="$1"\n' + assignments
                 + '\nprintf "%s\\n" "$DMG_LAYOUT_MOUNT" "$MNT"', "_", work],
                capture_output=True, text=True, check=True,
            )
            mounts.extend(result.stdout.splitlines())
        self.assertEqual(len(set(mounts)), 4, "reused mount paths collide with prior disk-image registrations")
        self.assertEqual(len({Path(mount).name for mount in mounts}), 4, "Finder identifies disks by mount name")
        self.assertIn('"${DMG_LAYOUT_MOUNT:t}" "$APP"', source)
        self.assertIn('"${MNT:t}" "$APP"', source)

    def test_layout_unregisters_before_unmounting(self) -> None:
        source = (SCRIPT.parent / "package-release.sh").read_text()
        start = source.index("# Unmount, then eject.")
        end = source.index('diskutil eject "$DMG_LAYOUT_DEVICE"', start)
        commands = source[start:end]
        result = subprocess.run(
            ["/bin/zsh", "-c", "set -euo pipefail\n"
             "unregister_launchservices() { echo unregister; }\n"
             "diskutil() { echo unmount; }\n"
             "DMG_LAYOUT_MOUNT=/test/layout\n" + commands],
            capture_output=True, text=True,
        )
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual(result.stdout.splitlines(), ["unregister", "unmount"])


class RegistryInspection(unittest.TestCase):
    def test_python_inspections_reject_a_failed_dump(self) -> None:
        def failed_dump(*args, **kwargs):
            result = subprocess.CompletedProcess(args[0], 17, "", "dump failed")
            if kwargs.get("check"):
                result.check_returncode()
            return result

        with patch("subprocess.run", side_effect=failed_dump):
            for inspect in (lambda: registered("/test/NepalKit.app"),
                            lambda: UnregisterLaunchServices()._bundle_id_registered("probe")):
                with self.assertRaises(subprocess.CalledProcessError):
                    inspect()

    def test_shell_inspection_failure_and_path_boundaries(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            workspace = Path(directory)
            bundle = workspace / "NepalKit.app"
            bundle.mkdir()
            stub = workspace / "lsregister"
            helper = workspace / "unregister.sh"
            helper.write_text(SCRIPT.read_text().replace(f"LSREGISTER={LSREGISTER}", f'LSREGISTER="{stub}"'))
            resolved = str(bundle.resolve())
            cases = [
                (17, "", 1),
                (0, f"path: {resolved}.backup (0x123)\n", 0),
                (0, f"path: {resolved} (0x123)\n", 1),
                (0, f"path: {resolved}/Contents/Updater.app (0x123)\n", 1),
            ]
            for dump_exit, dump, expected_exit in cases:
                with self.subTest(dump_exit=dump_exit, dump=dump):
                    stub.write_text('#!/bin/bash\nif [ "$1" = -dump ]; then\n'
                                    + "cat <<'DUMP'\n" + dump + "DUMP\n"
                                    + f"exit {dump_exit}\nfi\nexit 0\n")
                    stub.chmod(0o755)
                    result = subprocess.run(["/bin/bash", str(helper), str(bundle)], capture_output=True, text=True)
                    self.assertEqual(result.returncode, expected_exit, result.stdout + result.stderr)
                    if dump_exit:
                        self.assertNotIn("unregistered:", result.stdout)
                        self.assertIn("inspect", result.stderr)


if __name__ == "__main__":
    unittest.main()
