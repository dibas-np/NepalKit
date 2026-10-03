#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Dibas Sigdel
"""Exercise the cask updater with isolated download and authentication stubs."""

import os
from pathlib import Path
import plistlib
import re
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
IDENTIFIER = "com.dibas.NepalKit.NepalKit"
CASK = '''cask "nepalkit" do
  version "1.3.0"
  sha256 "old-digest"
  url "https://example.com/releases/download/v#{version}/NepalKit.dmg"
end
'''
STUB = '''#!/usr/bin/env python3
import os
from pathlib import Path
import shutil
import sys
name = Path(sys.argv[0]).name
with open(os.environ["STUB_LOG"], "a") as log:
    log.write(name + "\\n")
if name == os.environ.get("STUB_FAIL"):
    sys.exit(1)
if name == "curl":
    Path(sys.argv[sys.argv.index("-o") + 1]).write_bytes(b"fixture disk image")
elif name == "hdiutil" and sys.argv[1] == "attach":
    mount = Path(sys.argv[sys.argv.index("-mountpoint") + 1])
    shutil.copytree(os.environ["STUB_APP"], mount / "NepalKit.app")
elif name == "codesign":
    print("TeamIdentifier=" + os.environ["STUB_TEAM"], file=sys.stderr)
elif name == "shasum":
    print("a" * 64 + "  fixture")
'''


class CaskIdentityTests(unittest.TestCase):
    def run_updater(self, metadata, *, raw=None, requested="v1.4.0", rejected=True,
                    fail_command=""):
        with tempfile.TemporaryDirectory() as directory:
            tmp = Path(directory)
            app = tmp / "app/Contents"
            app.mkdir(parents=True)
            if raw is not None:
                (app / "Info.plist").write_bytes(raw)
            elif metadata is not None:
                (app / "Info.plist").write_bytes(plistlib.dumps(metadata))
            cask = tmp / "tap/Casks/nepalkit.rb"
            cask.parent.mkdir(parents=True)
            cask.write_text(CASK)
            binaries = tmp / "bin"
            binaries.mkdir()
            stub = binaries / "stub"
            stub.write_text(STUB)
            stub.chmod(0o755)
            for name in ("curl", "hdiutil", "spctl", "xcrun", "codesign", "shasum", "brew"):
                (binaries / name).symlink_to(stub)
            log = tmp / "commands"
            team = re.findall(r"DEVELOPMENT_TEAM = ([^;]+);",
                              (ROOT / "NepalKit.xcodeproj/project.pbxproj").read_text())[0]
            environment = dict(os.environ, PATH=f"{binaries}:{os.environ['PATH']}",
                               NEPAKIT_TAP_DIR=str(cask.parent.parent), STUB_APP=str(app.parent),
                               STUB_TEAM=team, STUB_LOG=str(log), STUB_FAIL=fail_command)
            environment.pop("TEAM_ID", None)
            result = subprocess.run([shutil.which("zsh"), str(ROOT / "scripts/update-cask.sh"),
                                     requested], env=environment, capture_output=True, text=True)
            if rejected:
                self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)
                self.assertEqual(cask.read_text(), CASK)
                self.assertNotIn("shasum", log.read_text().splitlines())
            else:
                self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
                self.assertIn('version "1.4.0"', cask.read_text())
                self.assertIn('sha256 "' + "a" * 64 + '"', cask.read_text())
                commands = log.read_text().splitlines()
                self.assertLess(commands.index("codesign"), commands.index("shasum"))
            return result

    def test_matching_product_and_normalized_requested_version(self):
        self.run_updater({"CFBundleIdentifier": IDENTIFIER,
                          "CFBundleShortVersionString": "1.4.0"}, rejected=False)

    def test_other_versions_are_rejected(self):
        for version in ("1.3.0", "1.5.0"):
            with self.subTest(version=version):
                self.run_updater({"CFBundleIdentifier": IDENTIFIER,
                                  "CFBundleShortVersionString": version})

    def test_authentication_failures_still_stop_before_hashing(self):
        for command in ("spctl", "xcrun", "codesign"):
            with self.subTest(command=command):
                self.run_updater({"CFBundleIdentifier": IDENTIFIER,
                                  "CFBundleShortVersionString": "1.4.0"},
                                 fail_command=command)

    def test_wrong_product_is_rejected(self):
        self.run_updater({"CFBundleIdentifier": IDENTIFIER + "Watch",
                          "CFBundleShortVersionString": "1.4.0"})

    def test_missing_and_malformed_plists_are_rejected(self):
        self.run_updater(None)
        self.run_updater(None, raw=b"not a plist")
        self.run_updater(None, raw=plistlib.dumps(["not a dictionary"]))

    def test_missing_blank_and_wrong_type_fields_are_rejected(self):
        for field in ("CFBundleIdentifier", "CFBundleShortVersionString"):
            for value in (None, "", 14):
                with self.subTest(field=field, value=value):
                    metadata = {"CFBundleIdentifier": IDENTIFIER,
                                "CFBundleShortVersionString": "1.4.0"}
                    if value is None:
                        del metadata[field]
                    else:
                        metadata[field] = value
                    self.run_updater(metadata)


if __name__ == "__main__":
    unittest.main()
