#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Dibas Sigdel

from __future__ import annotations

import base64
import importlib.util
import json
import subprocess
import tempfile
import unittest
from pathlib import Path

import sparkle_tools

_SCRIPT = Path(__file__).resolve().parent / "check-signing-key.py"
_spec = importlib.util.spec_from_file_location("check_signing_key", _SCRIPT)
csk = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(csk)


def keypair(directory: Path, name: str) -> tuple[Path, bytes]:
    pem = directory / f"{name}.pem"
    subprocess.run(["openssl", "genpkey", "-algorithm", "ed25519", "-out", str(pem)], check=True)
    der = subprocess.run(["openssl", "pkey", "-in", str(pem), "-pubout", "-outform", "DER"],
                         check=True, capture_output=True).stdout
    return pem, der[-32:]


def plist_with(directory: Path, public_key: bytes) -> Path:
    path = directory / "Info.plist"
    path.write_text(f"<plist><dict><key>SUPublicEDKey</key><string>"
                    f"{base64.b64encode(public_key).decode()}</string></dict></plist>")
    return path


def openssl_signer(pem: Path):
    def sign(path: Path) -> str:
        out = subprocess.run(["openssl", "pkeyutl", "-sign", "-rawin", "-inkey", str(pem), "-in", str(path)],
                             check=True, capture_output=True).stdout
        return base64.b64encode(out).decode()
    return sign


class Check(unittest.TestCase):
    def setUp(self):
        self._tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self._tmp.cleanup)
        self.dir = Path(self._tmp.name)

    def test_the_matching_key_passes(self):
        pem, public = keypair(self.dir, "a")
        ok, message = csk.check(plist_with(self.dir, public), openssl_signer(pem))
        self.assertTrue(ok, message)

    def test_a_different_key_fails(self):
        pem, _ = keypair(self.dir, "a")
        _, other_public = keypair(self.dir, "b")
        ok, message = csk.check(plist_with(self.dir, other_public), openssl_signer(pem))
        self.assertFalse(ok)
        self.assertIn("does NOT match", message)

    def test_a_signer_that_fails_is_a_failure(self):
        _, public = keypair(self.dir, "a")

        def broken(_path):
            raise RuntimeError("sign_update exited 1: no key")

        ok, message = csk.check(plist_with(self.dir, public), broken)
        self.assertFalse(ok)
        self.assertIn("could not sign", message)

    def test_garbage_output_is_a_failure(self):
        _, public = keypair(self.dir, "a")
        ok, _ = csk.check(plist_with(self.dir, public), lambda _p: "not base64!")
        self.assertFalse(ok)

    def test_a_sign_update_that_hangs_times_out_as_a_failure(self):
        _, public = keypair(self.dir, "a")
        slow = self.dir / "slow_sign_update"
        slow.write_text("#!/bin/sh\nsleep 5\n")
        slow.chmod(0o755)
        ok, message = csk.check(plist_with(self.dir, public), csk.sparkle_signer(slow, None, timeout=0.5))
        self.assertFalse(ok)
        self.assertIn("did not finish", message)

    def test_a_key_sign_update_echoes_back_is_not_printed(self):
        _, public = keypair(self.dir, "a")
        seed = base64.b64encode(bytes(range(32))).decode()
        for typed in (seed, seed.rstrip("="), seed[:10] + seed[12:]):
            key_file = self.dir / "typed.key"
            key_file.write_text(typed)
            echoing = self.dir / "echoing_sign_update"
            echoing.write_text('#!/bin/sh\nwhile [ "$1" != --ed-key-file ]; do shift; done\n'
                               'echo "ERROR! Failed to decode base64 encoded key data from: $(cat "$2")"\n'
                               "exit 1\n")
            echoing.chmod(0o755)
            ok, message = csk.check(plist_with(self.dir, public), csk.sparkle_signer(echoing, key_file))
            self.assertFalse(ok)
            self.assertIn("Failed to decode", message)
            self.assertNotIn(typed, message)
            self.assertNotIn(typed[:16], message)

    def test_a_missing_sign_update_fails_cleanly(self):
        self.assertEqual(csk.main(["--sign-update", str(self.dir / "absent")]), 1)


class SparkleBin(unittest.TestCase):
    def _load(self, env: dict[str, str]):
        import os
        saved = os.environ.copy()
        os.environ.pop("SPARKLE_BIN", None)
        os.environ.update(env)
        try:
            spec = importlib.util.spec_from_file_location("csk_env", _SCRIPT)
            module = importlib.util.module_from_spec(spec)
            spec.loader.exec_module(module)
            return module
        finally:
            os.environ.clear()
            os.environ.update(saved)

    def test_sparkle_bin_overrides_where_sign_update_is_found(self):
        module = self._load({"SPARKLE_BIN": "/opt/sparkle/bin"})
        self.assertEqual(module.SIGN_UPDATE, Path("/opt/sparkle/bin/sign_update"))

    def test_without_it_the_checkouts_own_build_is_used(self):
        module = self._load({})
        self.assertTrue(str(module.SIGN_UPDATE).endswith("DerivedData/SourcePackages/artifacts/sparkle/Sparkle/bin/sign_update"))
        self.assertTrue(module.SIGN_UPDATE.is_relative_to(module.ROOT))


class PinnedTools(unittest.TestCase):
    ORIGIN = "https://github.com/sparkle-project/Sparkle"

    def setUp(self):
        self._tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self._tmp.cleanup)
        root = Path(self._tmp.name)
        self.bin = root / "SourcePackages/artifacts/sparkle/Sparkle/bin"
        self.bin.mkdir(parents=True)
        self.tool = self.bin / "sign_update"
        self.tool.write_text("#!/bin/sh\n")
        self.checkout = root / "SourcePackages/checkouts/Sparkle"
        self.checkout.mkdir(parents=True)
        git = ["git", "-C", str(self.checkout), "-c", "user.name=t", "-c", "user.email=t@t", "-c", "commit.gpgsign=false",
               "-c", "tag.gpgsign=false"]
        subprocess.run([*git, "init", "-q"], check=True)
        subprocess.run([*git, "commit", "-q", "--allow-empty", "-m", "x"], check=True)
        subprocess.run([*git, "tag", "2.10.0"], check=True)
        subprocess.run([*git, "remote", "add", "origin", self.ORIGIN + ".git"], check=True)
        self.revision = subprocess.run([*git, "rev-parse", "HEAD"], check=True, capture_output=True,
                                       text=True).stdout.strip()
        self.project = root / "project.pbxproj"
        self.project.write_text('/* XCRemoteSwiftPackageReference "Sparkle" */ = {\n\trequirement = {\n'
                                "\t\tkind = exactVersion;\n\t\tversion = 2.10.0;\n\t};\n};\n")
        self.resolved = root / "Package.resolved"
        self.pin(self.revision)

    def pin(self, revision, location=ORIGIN):
        self.resolved.write_text(json.dumps({"pins": [{"identity": "sparkle", "location": location,
                                                       "state": {"revision": revision, "version": "2.10.0"}}]}))

    def problem(self, tool=None):
        return sparkle_tools.tool_problem(tool or self.tool, self.project, self.resolved)

    def test_the_pinned_release_passes(self):
        self.assertIsNone(self.problem())

    def test_a_checkout_at_another_revision_is_refused(self):
        self.pin("0" * 40)
        self.assertIn("revision", self.problem())

    def test_a_checkout_from_another_origin_is_refused(self):
        self.pin(self.revision, "https://github.com/someone/Sparkle")
        self.assertIn("does not come from", self.problem())

    def mirror_checkout(self, mirror):
        subprocess.run(["git", "clone", "-q", "--bare", str(self.checkout), str(mirror)], check=True)
        subprocess.run(["git", "-C", str(mirror), "remote", "set-url", "origin", self.ORIGIN], check=True)
        subprocess.run(["git", "-C", str(self.checkout), "remote", "set-url", "origin", str(mirror)], check=True)

    def test_a_checkout_of_swiftpms_mirror_follows_the_mirrors_origin(self):
        self.mirror_checkout(Path(self._tmp.name) / "SourcePackages/repositories/Sparkle-0")
        self.assertIsNone(self.problem())

    def test_a_checkout_of_a_mirror_elsewhere_is_refused(self):
        self.mirror_checkout(Path(self._tmp.name) / "elsewhere/Sparkle-0")
        self.assertIn("does not come from", self.problem())

    def test_a_checkout_without_the_pinned_tag_is_refused(self):
        subprocess.run(["git", "-C", str(self.checkout), "tag", "-d", "2.10.0"], check=True, capture_output=True)
        self.assertIn("not tagged 2.10.0", self.problem())

    def test_a_tool_linked_from_outside_its_directory_is_refused(self):
        outside = Path(self._tmp.name) / "elsewhere"
        outside.write_text("#!/bin/sh\n")
        self.tool.unlink()
        self.tool.symlink_to(outside)
        self.assertIn("resolves outside", self.problem())

    def test_main_refuses_an_unpinned_sign_update_before_running_it(self):
        stray = Path(self._tmp.name) / "stray" / "sign_update"
        stray.parent.mkdir()
        stray.write_text("#!/bin/sh\ntouch ran\n")
        stray.chmod(0o755)
        self.assertEqual(csk.main(["--sign-update", str(stray)]), 1)
        self.assertFalse((stray.parent / "ran").exists())


if __name__ == "__main__":
    unittest.main()
