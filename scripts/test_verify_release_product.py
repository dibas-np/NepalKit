#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Dibas Sigdel

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
    "SUSignedFeedFailureExpirationInterval": 0.0,
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

    def run_case(self, signed=None, info=None, sparkle="2.10.0", pin=None, expected=None, codesign_exit=0,
                 source_key=None, helpers=None, helper_signature=None, helper_entitlements=None):
        app = self.root / "NepalKit.app"
        (app / "Contents/Frameworks/Sparkle.framework/Resources").mkdir(parents=True, exist_ok=True)
        for name in vrp.SPARKLE_HELPERS if helpers is None else helpers:
            (app / vrp.SPARKLE_VERSION_DIR / name).parent.mkdir(parents=True, exist_ok=True)
            (app / vrp.SPARKLE_VERSION_DIR / name).touch()
        source = self.root / "Info.plist"
        with open(source, "wb") as fh:
            plistlib.dump({**GOOD_INFO, **({"SUPublicEDKey": source_key} if source_key else {})}, fh)
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

        app_signature = b"CodeDirectory v=20500 flags=0x10000(runtime)\nTeamIdentifier=CA89X9954L\n"

        def stub(cmd, **kwargs):
            self.assertEqual(cmd[:2], ["codesign", "-d"])
            is_app = cmd[-1] == str(app)
            if "--verbose=2" in cmd:
                signature = app_signature if is_app else (helper_signature or app_signature)
                return SimpleNamespace(stdout=b"", stderr=signature, returncode=0)
            if is_app:
                return SimpleNamespace(stdout=xml, stderr=b"codesign failed", returncode=codesign_exit)
            return SimpleNamespace(stdout=plistlib.dumps(helper_entitlements or {}), stderr=b"", returncode=0)

        out = io.StringIO()
        with contextlib.redirect_stdout(out):
            code = vrp.main([str(app), "--project", str(project), "--entitlements", str(ent),
                             "--info-plist", str(source)], run=stub)
        return code, out.getvalue()

    def test_exact_match_passes_with_four_ok_lines(self):
        code, out = self.run_case()
        self.assertEqual(code, 0, out)
        self.assertEqual(out.count("  ok "), 4, out)
        self.assertNotIn("FAIL", out)

    def test_a_failed_codesign_run_is_a_failure_even_with_xml(self):
        code, out = self.run_case(codesign_exit=1)
        self.assertEqual(code, 1, out)
        self.assertIn("codesign exited 1", out)

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

    def test_a_signed_feed_failure_expiry_fails(self):
        for value in (1728000.0, True):
            code, out = self.run_case(info={"SUSignedFeedFailureExpirationInterval": value})
            self.assertEqual(code, 1, value)
            self.assertIn("SUSignedFeedFailureExpirationInterval", out)

    def test_wrong_length_public_key_fails(self):
        code, out = self.run_case(info={"SUPublicEDKey": base64.b64encode(b"short").decode()})
        self.assertEqual(code, 1)
        self.assertIn("SUPublicEDKey", out)

    def test_a_public_key_other_than_the_sources_fails(self):
        code, out = self.run_case(source_key=base64.b64encode(bytes(32)).decode())
        self.assertEqual(code, 1)
        self.assertIn("not the source Info.plist's key", out)

    def test_a_missing_sparkle_helper_fails(self):
        code, out = self.run_case(helpers=vrp.SPARKLE_HELPERS[1:])
        self.assertEqual(code, 1)
        self.assertIn("Autoupdate is missing", out)

    def test_a_helper_from_another_team_fails(self):
        code, out = self.run_case(helper_signature=b"CodeDirectory flags=0x10000(runtime)\nTeamIdentifier=OTHER\n")
        self.assertEqual(code, 1)
        self.assertIn("signed by team OTHER", out)

    def test_a_helper_without_the_hardened_runtime_fails(self):
        code, out = self.run_case(helper_signature=b"CodeDirectory flags=0x0(none)\nTeamIdentifier=CA89X9954L\n")
        self.assertEqual(code, 1)
        self.assertIn("lacks the hardened runtime", out)

    def test_a_helper_with_an_extra_entitlement_fails(self):
        code, out = self.run_case(helper_entitlements={"com.apple.security.cs.disable-library-validation": True})
        self.assertEqual(code, 1)
        self.assertIn("disable-library-validation", out)

    def test_wrong_feed_url_fails(self):
        code, out = self.run_case(info={"SUFeedURL": "http://example.com/appcast.xml"})
        self.assertEqual(code, 1)
        self.assertIn("SUFeedURL", out)

    def test_another_feed_on_the_same_host_fails(self):
        code, out = self.run_case(info={"SUFeedURL": "https://dibas-np.github.io/NepalKit/other.xml"})
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

    def test_a_later_package_pin_is_not_read_as_sparkles(self):
        branch_pinned = (
            '/* XCRemoteSwiftPackageReference "Sparkle" */ = {\n'
            "\tisa = XCRemoteSwiftPackageReference;\n"
            "\trequirement = {\n\t\tkind = branch;\n\t\tbranch = 2.x;\n\t};\n};\n"
            '/* XCRemoteSwiftPackageReference "Other" */ = {\n'
            "\tisa = XCRemoteSwiftPackageReference;\n"
            "\trequirement = {\n\t\tkind = exactVersion;\n\t\tversion = 2.10.0;\n\t};\n};\n"
        )
        code, out = self.run_case(pin=branch_pinned)
        self.assertEqual(code, 1, out)
        self.assertIn("Sparkle pin kind is branch", out)

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
