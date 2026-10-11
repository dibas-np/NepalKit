#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Dibas Sigdel
"""Tests for verify-release-product.py, with codesign stubbed."""

import base64
import contextlib
import importlib.util
import io
import plistlib
import tempfile
import unittest
from pathlib import Path
from types import SimpleNamespace

SCRIPT = Path(__file__).with_name("verify-release-product.py")
spec = importlib.util.spec_from_file_location("verify_release_product", SCRIPT)
vrp = importlib.util.module_from_spec(spec)
spec.loader.exec_module(vrp)

BUNDLE_ID = "com.dibas.NepalKit.NepalKit"
GOOD_ENTITLEMENTS = {
    "com.apple.security.app-sandbox": True,
    "com.apple.security.network.client": True,
    "com.apple.security.temporary-exception.mach-lookup.global-name": [
        BUNDLE_ID + "-spks",
        BUNDLE_ID + "-spki",
    ],
}
FILE_ENTITLEMENTS = {
    "com.apple.security.app-sandbox": True,
    "com.apple.security.network.client": True,
    "com.apple.security.temporary-exception.mach-lookup.global-name": [
        "$(PRODUCT_BUNDLE_IDENTIFIER)-spks",
        "$(PRODUCT_BUNDLE_IDENTIFIER)-spki",
    ],
}
GOOD_INFO = {
    "CFBundleIdentifier": BUNDLE_ID,
    "SURequireSignedFeed": True,
    "SUVerifyUpdateBeforeExtraction": True,
    "SUEnableInstallerLauncherService": True,
    "SUPublicEDKey": base64.b64encode(bytes(range(32))).decode(),
    "SUFeedURL": "https://dibas-np.github.io/NepalKit/appcast.xml",
}


def pbxproj(kind="exactVersion", version="2.10.0"):
    return (
        '/* XCRemoteSwiftPackageReference "Sparkle" */ = {\n'
        "\tisa = XCRemoteSwiftPackageReference;\n"
        "\trequirement = {\n"
        f"\t\tkind = {kind};\n\t\tversion = {version};\n\t}};\n}};\n"
    )


class VerifyReleaseProductTests(unittest.TestCase):
    def setUp(self):
        self._tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self._tmp.cleanup)
        self.root = Path(self._tmp.name)

    def run_case(self, signed=None, info=None, sparkle="2.10.0", pin=None, expected=None):
        app = self.root / "NepalKit.app"
        (app / "Contents/Frameworks/Sparkle.framework/Resources").mkdir(parents=True, exist_ok=True)
        with open(app / "Contents/Info.plist", "wb") as fh:
            plistlib.dump({**GOOD_INFO, **(info or {})}, fh)
        with open(app / vrp.SPARKLE_FRAMEWORK_PLIST, "wb") as fh:
            plistlib.dump({"CFBundleShortVersionString": sparkle}, fh)
        project = self.root / "project.pbxproj"
        project.write_text(pin or pbxproj())
        ent = self.root / "NepalKit.entitlements"
        with open(ent, "wb") as fh:
            plistlib.dump(expected or FILE_ENTITLEMENTS, fh)
        xml = plistlib.dumps(signed if signed is not None else GOOD_ENTITLEMENTS)

        def stub(cmd, **kwargs):
            self.assertEqual(cmd[:2], ["codesign", "-d"])
            return SimpleNamespace(stdout=xml, returncode=0)

        out = io.StringIO()
        with contextlib.redirect_stdout(out):
            code = vrp.main([str(app), "--project", str(project), "--entitlements", str(ent)], run=stub)
        return code, out.getvalue()

    def test_exact_match_passes_with_three_ok_lines(self):
        code, out = self.run_case()
        self.assertEqual(code, 0, out)
        self.assertEqual(out.count("  ok "), 3, out)
        self.assertNotIn("FAIL", out)

    def test_extra_entitlement_in_product_fails(self):
        extra = {**GOOD_ENTITLEMENTS, "com.apple.security.files.user-selected.read-only": True}
        code, out = self.run_case(signed=extra)
        self.assertEqual(code, 1)
        self.assertIn("com.apple.security.files.user-selected.read-only", out)

    def test_missing_entitlement_fails(self):
        short = {k: v for k, v in GOOD_ENTITLEMENTS.items() if k != "com.apple.security.network.client"}
        code, out = self.run_case(signed=short)
        self.assertEqual(code, 1)
        self.assertIn("com.apple.security.network.client", out)

    def test_changed_value_fails(self):
        changed = {**GOOD_ENTITLEMENTS, "com.apple.security.app-sandbox": False}
        code, out = self.run_case(signed=changed)
        self.assertEqual(code, 1)
        self.assertIn("com.apple.security.app-sandbox", out)

    def test_get_task_allow_fails(self):
        code, out = self.run_case(signed={**GOOD_ENTITLEMENTS, "com.apple.security.get-task-allow": True})
        self.assertEqual(code, 1)
        self.assertIn("get-task-allow", out)

    def test_require_signed_feed_false_fails(self):
        code, out = self.run_case(info={"SURequireSignedFeed": False})
        self.assertEqual(code, 1)
        self.assertIn("SURequireSignedFeed", out)

    def test_wrong_length_public_key_fails(self):
        code, out = self.run_case(info={"SUPublicEDKey": base64.b64encode(b"short").decode()})
        self.assertEqual(code, 1)
        self.assertIn("SUPublicEDKey", out)

    def test_wrong_feed_url_fails(self):
        code, out = self.run_case(info={"SUFeedURL": "http://example.com/appcast.xml"})
        self.assertEqual(code, 1)
        self.assertIn("SUFeedURL", out)

    def test_sparkle_version_mismatch_names_both(self):
        code, out = self.run_case(sparkle="2.9.6")
        self.assertEqual(code, 1)
        self.assertIn("2.9.6", out)
        self.assertIn("2.10.0", out)

    def test_pin_kind_not_exact_fails(self):
        code, out = self.run_case(pin=pbxproj(kind="upToNextMajorVersion"))
        self.assertEqual(code, 1)
        self.assertIn("upToNextMajorVersion", out)

    def test_bundle_identifier_token_is_expanded(self):
        code, out = self.run_case(expected=FILE_ENTITLEMENTS)
        self.assertEqual(code, 0, out)

    def test_every_mismatch_is_reported_at_once(self):
        code, out = self.run_case(
            signed={**GOOD_ENTITLEMENTS, "x.extra": True},
            info={"SURequireSignedFeed": False},
            sparkle="2.9.6",
        )
        self.assertEqual(code, 1)
        self.assertEqual(out.count("FAIL"), 3, out)


if __name__ == "__main__":
    unittest.main()
