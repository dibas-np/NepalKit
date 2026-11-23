#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Dibas Sigdel
"""Check the exported app's entitlements, Sparkle keys, Sparkle version and Sparkle helpers."""

import argparse
import base64
import binascii
import plistlib
import subprocess
import sys
from pathlib import Path

from xcode_project import sparkle_pin

FEED_URL = "https://dibas-np.github.io/NepalKit/appcast.xml"
SPARKLE_FRAMEWORK_PLIST = "Contents/Frameworks/Sparkle.framework/Resources/Info.plist"
SPARKLE_VERSION_DIR = "Contents/Frameworks/Sparkle.framework/Versions/B"
SPARKLE_HELPERS = ("Autoupdate", "Updater.app", "XPCServices/Downloader.xpc", "XPCServices/Installer.xpc")
HELPER_ENTITLEMENTS = {"com.apple.application-identifier"}


def signed_entitlements(app, run=subprocess.run):
    result = run(
        ["codesign", "-d", "--entitlements", "-", "--xml", str(app)],
        capture_output=True,
    )
    if result.returncode != 0:
        detail = (getattr(result, "stderr", b"") or b"").decode("utf-8", "replace").strip()
        raise ValueError(f"codesign exited {result.returncode}" + (f": {detail}" if detail else ""))
    out = result.stdout
    start = out.find(b"<?xml")
    if start < 0:
        raise ValueError("codesign printed no XML entitlements plist")
    return plistlib.loads(out[start:])


def signature_details(path, run=subprocess.run):
    """The (TeamIdentifier, hardened runtime) codesign reports for `path`."""
    result = run(["codesign", "-d", "--verbose=2", str(path)], capture_output=True)
    if result.returncode != 0:
        raise ValueError(f"codesign exited {result.returncode}")
    text = (result.stderr or b"").decode("utf-8", "replace")
    team = next((line.split("=", 1)[1] for line in text.splitlines() if line.startswith("TeamIdentifier=")), None)
    runtime = any(line.startswith("CodeDirectory") and "(runtime)" in line for line in text.splitlines())
    return team, runtime


def _expand(value, bundle_id):
    if isinstance(value, str):
        return value.replace("$(PRODUCT_BUNDLE_IDENTIFIER)", bundle_id)
    if isinstance(value, list):
        return [_expand(v, bundle_id) for v in value]
    return value


def check_entitlements(app, info, entitlements_path, run):
    bundle_id = info.get("CFBundleIdentifier", "")
    with open(entitlements_path, "rb") as fh:  # NOSONAR
        expected = {k: _expand(v, bundle_id) for k, v in plistlib.load(fh).items()}
    try:
        actual = signed_entitlements(app, run)
    except Exception as exc:  # noqa: BLE001 - reported as a failure, not raised
        return [("FAIL", f"could not read signed entitlements: {exc}")]
    results = []
    for key in sorted(set(actual) - set(expected)):
        results.append(("FAIL", f"entitlement {key} is in the product and absent from the entitlements file"))
    for key in sorted(set(expected) - set(actual)):
        results.append(("FAIL", f"entitlement {key} is in the entitlements file and absent from the product"))
    for key in sorted(set(actual) & set(expected)):
        if actual[key] != expected[key]:
            results.append(("FAIL", f"entitlement {key} differs: product {actual[key]!r}, file {expected[key]!r}"))
    if "com.apple.security.get-task-allow" in actual:
        results.append(("FAIL", "com.apple.security.get-task-allow is present in the product"))
    if not results:
        results.append(("ok", f"signed entitlements match the entitlements file exactly ({len(actual)} keys)"))
    return results


def check_sparkle_keys(info, source_info):
    results = []
    for key in ("SURequireSignedFeed", "SUVerifyUpdateBeforeExtraction", "SUEnableInstallerLauncherService"):
        if info.get(key) is not True:
            results.append(("FAIL", f"{key} is {info.get(key)!r}, expected true"))
    key_value = info.get("SUPublicEDKey")
    try:
        length = len(base64.b64decode(key_value, validate=True)) if isinstance(key_value, str) else None
    except (binascii.Error, ValueError):
        length = None
    if length != 32:
        results.append(("FAIL", f"SUPublicEDKey is not base64 of 32 bytes (decoded length {length})"))
    if key_value != source_info.get("SUPublicEDKey"):
        results.append(("FAIL", f"SUPublicEDKey is {key_value!r}, not the source Info.plist's key"))
    interval = info.get("SUSignedFeedFailureExpirationInterval")
    if isinstance(interval, bool) or not isinstance(interval, (int, float)) or interval != 0:
        results.append(("FAIL", f"SUSignedFeedFailureExpirationInterval is {interval!r}, expected 0"))
    feed = info.get("SUFeedURL")
    if feed != FEED_URL:
        results.append(("FAIL", f"SUFeedURL is {feed!r}, expected {FEED_URL}"))
    if not results:
        results.append(("ok", "Sparkle keys present: signed feed, verify-before-extraction, "
                              "installer launcher, no signed-feed expiry, the source's public key, "
                              "pinned feed URL"))
    return results


def check_sparkle_version(app, pbxproj_text):
    try:
        pinned = sparkle_pin(pbxproj_text)
    except SystemExit as exc:
        return [("FAIL", str(exc))]
    plist_path = app / SPARKLE_FRAMEWORK_PLIST
    try:
        with open(plist_path, "rb") as fh:  # NOSONAR
            embedded = plistlib.load(fh).get("CFBundleShortVersionString")
    except OSError as exc:
        return [("FAIL", f"embedded Sparkle framework plist unreadable: {exc}")]
    if embedded != pinned:
        return [("FAIL", f"embedded Sparkle is {embedded}, project pins {pinned}")]
    return [("ok", f"embedded Sparkle {embedded} matches the exactVersion pin")]


def check_sparkle_helpers(app, run):
    try:
        team, _ = signature_details(app, run)
    except ValueError as exc:
        return [("FAIL", f"could not read the app's signature: {exc}")]
    results = []
    for name in SPARKLE_HELPERS:
        helper = app / SPARKLE_VERSION_DIR / name
        if not helper.exists():
            results.append(("FAIL", f"Sparkle helper {name} is missing"))
            continue
        try:
            helper_team, runtime = signature_details(helper, run)
            entitlements = signed_entitlements(helper, run)
        except ValueError as exc:
            results.append(("FAIL", f"could not read the signature of Sparkle helper {name}: {exc}"))
            continue
        if helper_team != team:
            results.append(("FAIL", f"Sparkle helper {name} is signed by team {helper_team}, the app by {team}"))
        if not runtime:
            results.append(("FAIL", f"Sparkle helper {name} lacks the hardened runtime"))
        for key in sorted(set(entitlements) - HELPER_ENTITLEMENTS):
            results.append(("FAIL", f"Sparkle helper {name} has entitlement {key}"))
    if not results:
        results.append(("ok", f"{len(SPARKLE_HELPERS)} Sparkle helpers: team {team}, hardened runtime, "
                              "no entitlements beyond an application identifier"))
    return results


def verify(app, project, entitlements, source_info, run=subprocess.run):
    app = Path(app)
    with open(app / "Contents/Info.plist", "rb") as fh:  # NOSONAR
        info = plistlib.load(fh)
    with open(source_info, "rb") as fh:  # NOSONAR
        source = plistlib.load(fh)
    results = []
    results += check_entitlements(app, info, entitlements, run)
    results += check_sparkle_keys(info, source)
    results += check_sparkle_helpers(app, run)
    project_text = Path(project).read_text()  # NOSONAR
    results += check_sparkle_version(app, project_text)
    return results


def main(argv=None, run=subprocess.run):
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("app")
    parser.add_argument("--project", required=True)
    parser.add_argument("--entitlements", required=True)
    parser.add_argument("--info-plist", required=True, help="the source Info.plist the app was built from")
    args = parser.parse_args(argv)
    results = verify(args.app, args.project, args.entitlements, args.info_plist, run)
    failed = False
    for status, message in results:
        print(f"  {status:<5} {message}")
        failed |= status == "FAIL"
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
