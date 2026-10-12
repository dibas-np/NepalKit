#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Dibas Sigdel
"""Prove a Sparkle EdDSA private key matches the public key the app ships.

Signs a scratch file with the pinned `sign_update` and verifies the signature
against `SUPublicEDKey` in NepalKit/Info.plist. --key-file signs with a backup
copy instead of the login keychain, so a restore can be tested without
importing anything (ADR-0012).

    scripts/check-signing-key.py                      # the keychain key
    scripts/check-signing-key.py --key-file PATH      # a backup copy

Run it on the release machine. Output never includes key material, only
sign_update's message and the key file's path on failure; nothing is written
outside a temporary directory. SPARKLE_BIN overrides where sign_update is
found, as for scripts/verify-appcast.sh.
"""

from __future__ import annotations

import argparse
import base64
import importlib.util
import os
import subprocess
import sys
import tempfile
from pathlib import Path
from typing import Callable

ROOT = Path(__file__).resolve().parent.parent
# This checkout's build of the pinned Sparkle, unless SPARKLE_BIN names the
# tools' directory. sign_update reaches the private key, so it is never
# whichever DerivedData matches a glob.
SIGN_UPDATE = (Path(os.environ["SPARKLE_BIN"]) / "sign_update" if os.environ.get("SPARKLE_BIN")
               else ROOT / "DerivedData/SourcePackages/artifacts/sparkle/Sparkle/bin/sign_update")

_spec = importlib.util.spec_from_file_location("verify_appcast", ROOT / "scripts" / "verify-appcast.py")
_va = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(_va)


SIGN_TIMEOUT_SECONDS = 120


def sparkle_signer(sign_update: Path, key_file: Path | None,
                   timeout: float = SIGN_TIMEOUT_SECONDS) -> Callable[[Path], str]:
    """A signer that runs `sign_update -p`, which prints only the base64 signature.

    The timeout turns an unanswered keychain access prompt into a failure
    rather than a hang.
    """
    def sign(path: Path) -> str:
        command = [str(sign_update), "-p", str(path)]
        if key_file is not None:
            command += ["--ed-key-file", str(key_file)]
        try:
            result = subprocess.run(command, capture_output=True, text=True, timeout=timeout)
        except subprocess.TimeoutExpired:
            raise RuntimeError(f"sign_update did not finish within {timeout:g} s; "
                               "was a keychain prompt left unanswered?") from None
        if result.returncode != 0:
            raise RuntimeError(f"sign_update exited {result.returncode}: {result.stderr.strip() or result.stdout.strip()}")
        return result.stdout.strip()
    return sign


def check(info_plist: Path, sign: Callable[[Path], str]) -> tuple[bool, str]:
    """(ok, message): does the signer's key match the shipped public key?"""
    public_key = _va.load_public_key(info_plist)
    with tempfile.TemporaryDirectory() as tmp:
        scratch = Path(tmp) / "scratch.bin"
        data = os.urandom(4096)
        scratch.write_bytes(data)
        try:
            signature = base64.b64decode(sign(scratch), validate=True)
        except Exception as exc:  # noqa: BLE001 - reported as a failure
            return False, f"could not sign a scratch file: {exc}"
    if _va.verify_signature(public_key, data, signature):
        return True, "the private key signs what the shipped SUPublicEDKey verifies"
    return False, "the private key does NOT match SUPublicEDKey in Info.plist; it cannot sign updates"


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    parser.add_argument("--key-file", type=Path, help="a backup key file (base64, as written by generate_keys -x)")
    parser.add_argument("--info-plist", type=Path, default=ROOT / "NepalKit" / "Info.plist")
    parser.add_argument("--sign-update", type=Path, default=SIGN_UPDATE)
    args = parser.parse_args(argv)
    if not args.sign_update.is_file():
        print(f"  FAIL  no sign_update at {args.sign_update}; run scripts/check-all.sh once to build it")
        return 1
    ok, message = check(args.info_plist, sparkle_signer(args.sign_update, args.key_file))
    source = f"key file {args.key_file}" if args.key_file else "login keychain"
    print(("  ok    " if ok else "  FAIL  ") + f"{source}: {message}")
    return 0 if ok else 1


if __name__ == "__main__":
    raise SystemExit(main())
