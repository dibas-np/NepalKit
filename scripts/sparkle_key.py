# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Dibas Sigdel
"""The Sparkle EdDSA public key in Info.plist, and checking a signature with it."""

from __future__ import annotations

import base64
import plistlib
import subprocess
import tempfile
from pathlib import Path
from typing import NoReturn

# DER prefix for an Ed25519 SubjectPublicKeyInfo (RFC 8410), so openssl can
# read the raw key from Info.plist.
ED25519_SPKI_PREFIX = bytes.fromhex("302a300506032b6570032100")


def fail(message: str) -> NoReturn:
    print(f"  FAIL  {message}")
    raise SystemExit(1)


def ok(message: str) -> None:
    print(f"  ok    {message}")


def load_public_key(info_plist: Path) -> bytes:
    try:
        with open(info_plist, "rb") as fh:  # NOSONAR
            encoded = plistlib.load(fh).get("SUPublicEDKey")
    except (OSError, plistlib.InvalidFileException) as exc:
        fail(f"cannot read {info_plist} as a property list: {exc}")
    if encoded is None:
        fail(f"{info_plist} has no SUPublicEDKey")
    if not isinstance(encoded, str):
        fail(f"SUPublicEDKey is a {type(encoded).__name__}, not a string")
    try:
        key = base64.b64decode(encoded.strip(), validate=True)
    except Exception as exc:  # noqa: BLE001
        fail(f"SUPublicEDKey is not valid base64: {exc}")
    if len(key) != 32:
        fail(f"SUPublicEDKey decodes to {len(key)} bytes, expected 32 for Ed25519")
    return key


def verify_signature(public_key: bytes, data: bytes, signature: bytes) -> bool:
    with tempfile.TemporaryDirectory() as tmp:
        tmp_path = Path(tmp)
        (tmp_path / "spki.der").write_bytes(ED25519_SPKI_PREFIX + public_key)
        (tmp_path / "data.bin").write_bytes(data)  # NOSONAR
        (tmp_path / "sig.bin").write_bytes(signature)
        result = subprocess.run(
            [
                "openssl", "pkeyutl", "-verify",
                "-pubin", "-inkey", str(tmp_path / "spki.der"),
                "-keyform", "DER", "-rawin",
                "-in", str(tmp_path / "data.bin"),
                "-sigfile", str(tmp_path / "sig.bin"),
            ],
            capture_output=True,
            text=True,
        )
    if result.returncode == 0:
        return True
    if "Signature Verification Failure" in result.stdout:
        return False
    first_error = next(iter(result.stderr.strip().splitlines()), "no error output")
    fail(f"openssl could not check the signature ({first_error}). Ed25519 needs "
         "OpenSSL 3+ (macOS /usr/bin/openssl is LibreSSL); put Homebrew openssl "
         "first on PATH")
