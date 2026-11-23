#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later

import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path

ARCHIVE_SUM = "c3a1d77647ca18c1b7e9be7dbc6cd4490d26422f28814b76370244ff61970869"
BINARY_SUM = "52112ece2dfa99c2442a1367f9a365d43784714cf224c3675bf8bc2f18ebd7c8"


class SwiftLintBootstrap(unittest.TestCase):
    def setUp(self):
        self._tmp = tempfile.TemporaryDirectory(prefix="nk lint bootstrap ")
        self.addCleanup(self._tmp.cleanup)
        self.root = Path(self._tmp.name)
        scripts = self.root / "scripts"
        scripts.mkdir()
        source = Path(__file__).resolve().parent
        shutil.copy(source / "swiftlint.sh", scripts / "swiftlint.sh")
        shutil.copy(source.parent / ".swiftlint-version", self.root / ".swiftlint-version")
        self.version = (self.root / ".swiftlint-version").read_text().strip()
        self.tools = self.root / "fake tools"
        self.tools.mkdir()
        stubs = {
            "curl": "#!/bin/bash\nexit 0\n",
            # The real digests, keyed by what is hashed; a file containing "tampered" hashes to something else.
            "shasum": f'''#!/bin/bash
if grep -q tampered "$3" 2>/dev/null; then echo 0000; elif [[ "$3" == *.zip ]]; then echo {ARCHIVE_SUM}; else echo {BINARY_SUM}; fi
''',
            "unzip": '''#!/bin/bash
bundle="$4/SwiftLintBinary.artifactbundle"
mkdir -p "$bundle/linux/amd64" "$bundle/macos"
printf '#!/bin/bash\\nexit 99\\n' > "$bundle/linux/amd64/swiftlint"
printf '#!/bin/bash\\necho %s\\n' "$NK_TEST_VERSION" > "$bundle/macos/swiftlint"
''',
            # Reports the pinned version, which the old version check would have accepted.
            "swiftlint": '#!/bin/bash\necho "$NK_TEST_VERSION"\necho from-path >&2\n',
        }
        for name, contents in stubs.items():
            stub = self.tools / name
            stub.write_text(contents)
            stub.chmod(0o755)
        self.cached = self.root / ".build/tools/swiftlint" / self.version / "swiftlint"

    def run_lint(self):
        return subprocess.run(
            ["/bin/bash", str(self.root / "scripts/swiftlint.sh"), "version"],
            env={"PATH": f"{self.tools}:/usr/bin:/bin", "NK_TEST_VERSION": self.version},
            capture_output=True, text=True,
        )

    def test_selects_the_macos_binary_and_reuses_it(self):
        for _ in range(2):
            result = self.run_lint()
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            self.assertEqual(result.stdout.strip(), self.version)
        self.assertTrue(self.cached.is_file())

    def test_a_swiftlint_on_path_is_not_used(self):
        result = self.run_lint()
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertNotIn("from-path", result.stdout + result.stderr)

    def test_a_cached_binary_that_changed_is_refused(self):
        self.assertEqual(self.run_lint().returncode, 0)
        self.cached.write_text("#!/bin/bash\n# tampered\necho %s\n" % self.version)
        result = self.run_lint()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("is not the pinned SwiftLint", result.stderr)


if __name__ == "__main__":
    unittest.main()
