#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Checks the pinned SwiftLint bootstrap without downloading an archive."""

import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path


class SwiftLintBootstrap(unittest.TestCase):
    def test_selects_the_macos_binary_and_reuses_it(self):
        with tempfile.TemporaryDirectory(prefix="nk lint bootstrap ") as directory:
            root = Path(directory)
            scripts = root / "scripts"
            scripts.mkdir()
            source = Path(__file__).resolve().parent
            shutil.copy(source / "swiftlint.sh", scripts / "swiftlint.sh")
            shutil.copy(source.parent / ".swiftlint-version", root / ".swiftlint-version")
            version = (root / ".swiftlint-version").read_text().strip()
            tools = root / "fake tools"
            tools.mkdir()
            stubs = {
                "find": '#!/bin/bash\nprintf "%s/SwiftLintBinary.artifactbundle/linux/amd64/swiftlint\\n" "$1"\n',
                "curl": "#!/bin/bash\nexit 0\n",
                "shasum": "#!/bin/bash\necho c3a1d77647ca18c1b7e9be7dbc6cd4490d26422f28814b76370244ff61970869\n",
                "unzip": '''#!/bin/bash
bundle="$4/SwiftLintBinary.artifactbundle"
mkdir -p "$bundle/linux/amd64" "$bundle/macos"
printf '#!/bin/bash\\nexit 99\\n' > "$bundle/linux/amd64/swiftlint"
printf '#!/bin/bash\\necho %s\\n' "$NK_TEST_VERSION" > "$bundle/macos/swiftlint"
''',
            }
            for name, contents in stubs.items():
                stub = tools / name
                stub.write_text(contents)
                stub.chmod(0o755)
            for _ in range(2):
                result = subprocess.run(
                    ["/bin/bash", str(scripts / "swiftlint.sh"), "version"],
                    env={"PATH": f"{tools}:/usr/bin:/bin", "NK_TEST_VERSION": version},
                    capture_output=True, text=True,
                )
                self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
                self.assertEqual(result.stdout.strip(), version)
            self.assertTrue((root / ".build/tools/swiftlint" / version / "swiftlint").is_file())


if __name__ == "__main__":
    unittest.main()
