#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Dibas Sigdel
"""The exported app's entitlements, Sparkle keys and Sparkle version, read off the product.

``NepalKit/NepalKit.entitlements`` is not the whole contract: Xcode merges
``ENABLE_*`` build settings into the entitlements at signing, which is how 1.6.0
shipped ``com.apple.security.files.user-selected.read-only`` from
``ENABLE_USER_SELECTED_FILES = readonly``. The embedded Sparkle version is
compared with the project's pin because package resolution on the build machine
can drift from it.

Run by ``package-release.sh`` on the exported app, before notarisation (which
also checks hardened runtime). Every check prints ``ok`` or ``FAIL``; any FAIL
exits 1 after all are reported.
"""

import argparse
import base64
import binascii
import plistlib
import re
import subprocess
import sys
from pathlib import Path

# NOSONAR: the four opens below take CLI-argument paths. package-release.sh runs
# this inside a private `mktemp -d` workspace outside the repo, so confining paths
# to a base directory would break every release (see scripts/verify-appcast.py).
# NOSONAR is line-scoped, so each marker sits on the flagged call alone.

FEED_URL = "https://dibas-np.github.io/NepalKit/appcast.xml"
SPARKLE_FRAMEWORK_PLIST = "Contents/Frameworks/Sparkle.framework/Resources/Info.plist"


def signed_entitlements(app, run=subprocess.run):
    """The entitlements actually signed into ``app``, as a dict."""
    result = run(
        ["codesign", "-d", "--entitlements", "-", "--xml", str(app)],
        capture_output=True,
    )
    # A failed codesign run is a failure even if it printed XML.
    if result.returncode != 0:
        detail = (getattr(result, "stderr", b"") or b"").decode("utf-8", "replace").strip()
        raise ValueError(f"codesign exited {result.returncode}" + (f": {detail}" if detail else ""))
    out = result.stdout
    start = out.find(b"<?xml")
    if start < 0:
        raise ValueError("codesign printed no XML entitlements plist")
    return plistlib.loads(out[start:])


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


def check_sparkle_keys(info):
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
    feed = info.get("SUFeedURL")
    if feed != FEED_URL:
        results.append(("FAIL", f"SUFeedURL is {feed!r}, expected {FEED_URL}"))
    if not results:
        results.append(("ok", "Sparkle keys present: signed feed, verify-before-extraction, "
                              "installer launcher, 32-byte public key, pinned feed URL"))
    return results


def check_sparkle_version(app, pbxproj_text):
    block = re.search(
        r'XCRemoteSwiftPackageReference "Sparkle".*?'
        r'kind = (?P<kind>\w+);\s*version = (?P<version>[\d.]+);',
        pbxproj_text, re.S)
    if not block:
        return [("FAIL", "no Sparkle exactVersion-style requirement found in the project")]
    results = []
    if block["kind"] != "exactVersion":
        results.append(("FAIL", f"Sparkle pin kind is {block['kind']}, expected exactVersion"))
    plist_path = app / SPARKLE_FRAMEWORK_PLIST
    try:
        with open(plist_path, "rb") as fh:  # NOSONAR
            embedded = plistlib.load(fh).get("CFBundleShortVersionString")
    except OSError as exc:
        return results + [("FAIL", f"embedded Sparkle framework plist unreadable: {exc}")]
    if embedded != block["version"]:
        results.append(("FAIL", f"embedded Sparkle is {embedded}, project pins {block['version']}"))
    elif not results:
        results.append(("ok", f"embedded Sparkle {embedded} matches the exactVersion pin"))
    return results


def verify(app, project, entitlements, run=subprocess.run):
    app = Path(app)
    with open(app / "Contents/Info.plist", "rb") as fh:  # NOSONAR
        info = plistlib.load(fh)
    results = []
    results += check_entitlements(app, info, entitlements, run)
    results += check_sparkle_keys(info)
    project_text = Path(project).read_text()  # NOSONAR
    results += check_sparkle_version(app, project_text)
    return results


def main(argv=None, run=subprocess.run):
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("app")
    parser.add_argument("--project", required=True)
    parser.add_argument("--entitlements", required=True)
    args = parser.parse_args(argv)
    results = verify(args.app, args.project, args.entitlements, run)
    failed = False
    for status, message in results:
        print(f"  {status:<5} {message}")
        failed |= status == "FAIL"
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
