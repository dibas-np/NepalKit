#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Dibas Sigdel
"""Suite for check-signing-key.py, using throwaway keys only: never the real one."""

from __future__ import annotations

import base64
import importlib.util
import subprocess
import tempfile
import unittest
from pathlib import Path

_SCRIPT = Path(__file__).resolve().parent / "check-signing-key.py"
_spec = importlib.util.spec_from_file_location("check_signing_key", _SCRIPT)
csk = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(csk)


def keypair(directory: Path, name: str) -> tuple[Path, bytes]:
    """A throwaway Ed25519 key in PEM, and its raw 32-byte public key."""
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

    def test_a_missing_sign_update_fails_cleanly(self):
        self.assertEqual(csk.main(["--sign-update", str(self.dir / "absent")]), 1)


if __name__ == "__main__":
    unittest.main()


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
        """As verify-appcast.sh does: SPARKLE_BIN names the tools' directory."""
        module = self._load({"SPARKLE_BIN": "/opt/sparkle/bin"})
        self.assertEqual(module.SIGN_UPDATE, Path("/opt/sparkle/bin/sign_update"))

    def test_without_it_the_checkouts_own_build_is_used(self):
        module = self._load({})
        self.assertTrue(str(module.SIGN_UPDATE).endswith("DerivedData/SourcePackages/artifacts/sparkle/Sparkle/bin/sign_update"))
        self.assertTrue(module.SIGN_UPDATE.is_relative_to(module.ROOT))
