#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Dibas Sigdel
"""Behavioural suite for scripts/release-core.sh.

Run: python3 scripts/test_release_core.py

Each test builds a throwaway repository, origin, mirror and SSH key, with gh,
swift and xcodebuild stubbed. git is real, so the assertions are about real
refs. Needs zsh, git and ssh-keygen; no network, no real key.
"""

from __future__ import annotations

import os
import re
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path
from unittest import mock

SCRIPTS = Path(__file__).resolve().parent
SCRIPT = SCRIPTS / "release-core.sh"
VERIFICATION_GUIDE = SCRIPTS.parent / "docs" / "release-verification.md"

CHANGELOG = """# Changelog

## 0.1.0 — 2026-11-04

- The first release.
"""

GH_STUB = """#!/bin/sh
# gh, as release-core.sh uses it: repo view, the release lookup, release create.
world="$(dirname "$0")/.."
case "$1 $2" in
  "repo view") exit 0 ;;
  "api "*)
    if [ -f "$world/released" ]; then echo "$(cat "$world/released")"; exit 0; fi
    echo "gh: Not Found (HTTP 404)" >&2; exit 1 ;;
  "release create")
    printf '%s\\n' "$@" >> "$world/gh-release.log"
    if [ "${STUB_GH_RELEASE_EXIT:-0}" != 0 ]; then exit "$STUB_GH_RELEASE_EXIT"; fi
    echo "$3" > "$world/released"; exit 0 ;;
esac
echo "unexpected gh call: $*" >&2
exit 2
"""

SUITE_STUB = """#!/bin/sh
echo "✔ Test run with 3 tests in 1 suite passed after 0.1 seconds."
"""


def git(*args: str, cwd: Path, check: bool = True) -> str:
    return subprocess.run(["git", *args], cwd=cwd, check=check, capture_output=True,
                          text=True).stdout.strip()


class World:
    """A repository, its origin, a mirror, a signing key and the tool stubs."""

    def __init__(self, root: Path) -> None:
        self.root = root
        self.repo = root / "repo"
        self.origin = root / "origin.git"
        self.mirror = root / "mirror.git"
        self.bin = root / "bin"
        self.home = root / "home"
        self.home.mkdir()
        self.bin.mkdir()
        for name, body in (("gh", GH_STUB), ("swift", SUITE_STUB), ("xcodebuild", SUITE_STUB)):
            stub = self.bin / name
            stub.write_text(body, encoding="utf-8")
            stub.chmod(0o755)

        key = root / "signing-key"
        subprocess.run(["ssh-keygen", "-q", "-t", "ed25519", "-N", "", "-C", "test", "-f", str(key)],
                       check=True)
        self.key = key
        self.fingerprint = subprocess.run(["ssh-keygen", "-lf", str(key)], check=True,
                                          capture_output=True, text=True).stdout.split()[1]
        self.allowed_signers = root / "allowed_signers"
        self.allowed_signers.write_text(
            f'release@example.com namespaces="git" {(root / "signing-key.pub").read_text()}',
            encoding="utf-8",
        )

        git("init", "--quiet", "--initial-branch=develop", str(self.repo), cwd=root)
        for key_name, value in (("user.name", "Release Test"), ("user.email", "release@example.com"),
                                ("gpg.format", "ssh"), ("user.signingkey", str(key)),
                                ("gpg.ssh.allowedSignersFile", str(self.allowed_signers))):
            git("config", key_name, value, cwd=self.repo)
        package = self.repo / "NepalKitCore"
        (package / "Sources" / "NepalKitCore").mkdir(parents=True)
        (package / "Package.swift").write_text("// swift-tools-version: 6.2\n", encoding="utf-8")
        (package / "CHANGELOG.md").write_text(CHANGELOG, encoding="utf-8")
        (package / "Sources" / "NepalKitCore" / "Core.swift").write_text("let core = 1\n", encoding="utf-8")
        (self.repo / "README.md").write_text("The app.\n", encoding="utf-8")
        (self.repo / "scripts").mkdir()
        shutil.copy2(SCRIPT, self.repo / "scripts" / "release-core.sh")
        self.commit("the package")

        git("init", "--quiet", "--bare", str(self.origin), cwd=root)
        git("remote", "add", "origin", str(self.origin), cwd=self.repo)
        git("push", "--quiet", "origin", "develop", cwd=self.repo)
        git("init", "--quiet", "--bare", "--initial-branch=main", str(self.mirror), cwd=root)

    def commit(self, message: str) -> None:
        git("add", "-A", cwd=self.repo)
        git("commit", "--quiet", "-m", message, cwd=self.repo)

    def run(self, *args: str, **overrides: str) -> subprocess.CompletedProcess:
        env = {
            "PATH": f"{self.bin}:{os.environ['PATH']}",
            "HOME": str(self.home),
            "TMPDIR": str(self.root),
            "GIT_CONFIG_NOSYSTEM": "1",
            "GIT_CONFIG_GLOBAL": os.devnull,
            "CORE_MIRROR_REPO": "example/NepalKitCore",
            "CORE_MIRROR_URL": str(self.mirror),
            "CORE_SIGNING_FINGERPRINT": self.fingerprint,
        }
        env.update(overrides)
        return subprocess.run(["zsh", str(self.repo / "scripts" / "release-core.sh"), *args],
                              cwd=self.repo, env=env, capture_output=True, text=True)

    def split(self) -> str:
        return git("subtree", "split", "--quiet", "--prefix=NepalKitCore", "HEAD", cwd=self.repo)

    def head(self) -> str:
        return git("rev-parse", "HEAD", cwd=self.repo)

    def refs(self, repository: Path) -> dict[str, str]:
        listed = git("ls-remote", str(repository), cwd=self.root)
        return {ref: sha for sha, ref in (line.split("\t") for line in listed.splitlines())}

    def staged(self) -> str:
        return git("for-each-ref", "refs/release-core/", cwd=self.repo)

    def releases(self) -> list[str]:
        log = self.root / "gh-release.log"
        return log.read_text(encoding="utf-8").splitlines() if log.exists() else []


class ReleaseCoreTest(unittest.TestCase):
    def setUp(self) -> None:
        scratch = tempfile.TemporaryDirectory()
        self.addCleanup(scratch.cleanup)
        # No system or global git config, for the World's git calls and the script's.
        isolated = mock.patch.dict(os.environ, {
            "HOME": str(Path(scratch.name) / "home"),
            "GIT_CONFIG_NOSYSTEM": "1",
            "GIT_CONFIG_GLOBAL": os.devnull,
        })
        isolated.start()
        self.addCleanup(isolated.stop)
        self.world = World(Path(scratch.name))

    def assertNothingPublished(self) -> None:
        self.assertEqual(self.world.refs(self.world.mirror), {})
        self.assertNotIn("refs/tags/core-v0.1.0", self.world.refs(self.world.origin))
        self.assertEqual(self.world.releases(), [])

    def test_a_malformed_version_is_refused(self) -> None:
        result = self.world.run("1.2")
        self.assertEqual(result.returncode, 1)
        self.assertIn("not a major.minor.patch version", result.stderr)

    def test_a_missing_changelog_entry_is_refused(self) -> None:
        result = self.world.run("0.2.0")
        self.assertEqual(result.returncode, 1, result.stdout)
        self.assertIn("no '## 0.2.0 — <date>' entry", result.stderr)
        self.assertNothingPublished()

    def test_an_undated_changelog_entry_is_refused(self) -> None:
        (self.world.repo / "NepalKitCore" / "CHANGELOG.md").write_text(
            CHANGELOG.replace("## 0.1.0", "## 0.2.0 — Unreleased\n\n- The second.\n\n## 0.1.0"),
            encoding="utf-8")
        self.world.commit("0.2.0")
        git("push", "--quiet", "origin", "develop", cwd=self.world.repo)
        result = self.world.run("0.2.0")
        self.assertEqual(result.returncode, 1, result.stdout)
        self.assertIn("heading has no YYYY-MM-DD release date", result.stderr)
        self.assertNothingPublished()

    def test_a_release_publishes_the_split_and_both_signed_tags(self) -> None:
        result = self.world.run("0.1.0")
        self.assertEqual(result.returncode, 0, result.stderr)

        mirror = self.world.refs(self.world.mirror)
        self.assertEqual(mirror["refs/heads/main"], self.world.split())
        self.assertEqual(mirror["refs/tags/v0.1.0^{}"], self.world.split())
        origin = self.world.refs(self.world.origin)
        self.assertEqual(origin["refs/tags/core-v0.1.0^{}"], self.world.head())
        for repository, tag in ((self.world.mirror, "v0.1.0"), (self.world.repo, "core-v0.1.0")):
            verified = subprocess.run(
                ["git", "-c", f"gpg.ssh.allowedSignersFile={self.world.allowed_signers}", "tag", "-v", tag],
                cwd=repository, capture_output=True, text=True,
            )
            self.assertIn(f'Good "git" signature for release@example.com with ED25519 key '
                          f'{self.world.fingerprint}', verified.stderr)
        # A v* tag here would read as an app release.
        self.assertEqual(git("tag", "--list", "v*", cwd=self.world.repo), "")
        self.assertEqual(self.world.staged(), "")
        releases = self.world.releases()
        self.assertEqual(releases.count("create"), 1)
        notes = Path(releases[releases.index("--notes-file") + 1])
        self.assertFalse(notes.exists(), "the notes file lives in the run's own directory")
        self.assertIn("--verify-tag", releases)

    def test_a_dry_run_signs_both_tags_and_pushes_nothing(self) -> None:
        result = self.world.run("--dry-run", "0.1.0")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout.count('Good "git" signature'), 2)
        self.assertIn("Nothing was pushed", result.stdout)
        self.assertNothingPublished()
        self.assertEqual(git("tag", "--list", cwd=self.world.repo), "")
        self.assertEqual(self.world.staged(), "")

    def test_a_dirty_tree_stops_a_release_but_only_warns_a_dry_run(self) -> None:
        (self.world.repo / "README.md").write_text("changed\n", encoding="utf-8")
        released = self.world.run("0.1.0")
        self.assertEqual(released.returncode, 1)
        self.assertIn("uncommitted changes", released.stderr)
        dry = self.world.run("--dry-run", "0.1.0")
        self.assertEqual(dry.returncode, 0, dry.stderr)
        self.assertIn("warning (dry run): the working tree has uncommitted changes", dry.stderr)
        self.assertNothingPublished()

    def test_an_unpushed_head_stops_a_release(self) -> None:
        (self.world.repo / "README.md").write_text("changed\n", encoding="utf-8")
        self.world.commit("not pushed")
        result = self.world.run("0.1.0")
        self.assertEqual(result.returncode, 1)
        self.assertIn("HEAD is not origin/develop", result.stderr)
        self.assertNothingPublished()

    def test_an_unreachable_mirror_fails_rather_than_reading_as_empty(self) -> None:
        result = self.world.run("0.1.0", CORE_MIRROR_URL=str(self.world.root / "missing.git"))
        self.assertEqual(result.returncode, 1)
        self.assertIn("cannot read refs/heads/main", result.stderr)
        self.assertNotIn("refs/tags/core-v0.1.0", self.world.refs(self.world.origin))
        self.assertEqual(self.world.releases(), [])

    def test_a_mirror_changed_outside_the_script_is_refused(self) -> None:
        stray = self.world.root / "stray"
        git("init", "--quiet", "--initial-branch=main", str(stray), cwd=self.world.root)
        (stray / "x").write_text("x\n", encoding="utf-8")
        git("add", "x", cwd=stray)
        git("-c", "user.name=x", "-c", "user.email=x@example.com", "commit", "--quiet", "-m", "stray",
            cwd=stray)
        git("push", "--quiet", str(self.world.mirror), "main", cwd=stray)

        result = self.world.run("0.1.0")
        self.assertEqual(result.returncode, 1)
        self.assertIn("has diverged from the split", result.stderr)
        self.assertNotIn("refs/tags/v0.1.0", self.world.refs(self.world.mirror))
        self.assertNotIn("refs/tags/core-v0.1.0", self.world.refs(self.world.origin))

    def test_a_published_tag_at_another_commit_is_refused(self) -> None:
        self.assertEqual(self.world.run("0.1.0").returncode, 0)
        (self.world.repo / "NepalKitCore" / "Sources" / "NepalKitCore" / "Core.swift").write_text(
            "let core = 2\n", encoding="utf-8")
        self.world.commit("a core change")
        git("push", "--quiet", "origin", "develop", cwd=self.world.repo)

        result = self.world.run("0.1.0")
        self.assertEqual(result.returncode, 1)
        self.assertIn("v0.1.0 on example/NepalKitCore is", result.stderr)
        self.assertIn("not this split", result.stderr)

    def test_a_tag_signed_by_another_key_is_refused_before_anything_is_pushed(self) -> None:
        result = self.world.run("0.1.0", CORE_SIGNING_FINGERPRINT="SHA256:not-the-documented-key")
        self.assertEqual(result.returncode, 1)
        self.assertIn("is not signed by SHA256:not-the-documented-key", result.stderr)
        self.assertNothingPublished()

    def test_signing_that_cannot_be_verified_is_refused(self) -> None:
        git("config", "--unset", "gpg.ssh.allowedSignersFile", cwd=self.world.repo)
        result = self.world.run("--dry-run", "0.1.0")
        self.assertEqual(result.returncode, 1)
        self.assertIn("no gpg.ssh.allowedSignersFile", result.stderr)

    def test_a_run_that_stopped_after_publishing_can_be_finished(self) -> None:
        first = self.world.run("0.1.0", STUB_GH_RELEASE_EXIT="1")
        self.assertNotEqual(first.returncode, 0)
        published = self.world.refs(self.world.mirror)
        self.assertIn("refs/tags/v0.1.0", published)

        second = self.world.run("0.1.0")
        self.assertEqual(second.returncode, 0, second.stderr)
        self.assertIn("v0.1.0 is already on example/NepalKitCore; verifying it", second.stdout)
        self.assertIn("core-v0.1.0 is already on origin; verifying it", second.stdout)
        # The published tag is the same object, not a re-signed replacement.
        self.assertEqual(self.world.refs(self.world.mirror), published)
        self.assertEqual(self.world.releases().count("create"), 2)
        self.assertTrue((self.world.root / "released").exists())

    def test_an_unsigned_published_tag_is_not_adopted(self) -> None:
        # A lightweight tag at the right commit, as a hand push would leave.
        git("push", "--quiet", str(self.world.mirror), f"{self.world.split()}:refs/heads/main",
            f"{self.world.split()}:refs/tags/v0.1.0", cwd=self.world.repo)
        result = self.world.run("0.1.0")
        self.assertEqual(result.returncode, 1)
        self.assertIn("v0.1.0 is not an annotated tag", result.stderr)
        self.assertNotIn("refs/tags/core-v0.1.0", self.world.refs(self.world.origin))
        self.assertEqual(self.world.releases(), [])

    def test_a_local_source_tag_that_origin_does_not_have_is_refused_up_front(self) -> None:
        git("tag", "core-v0.1.0", cwd=self.world.repo)
        result = self.world.run("0.1.0")
        self.assertEqual(result.returncode, 1)
        self.assertIn("git tag -d core-v0.1.0", result.stderr)
        self.assertNothingPublished()

    def test_a_mirror_tag_without_main_gets_its_main_on_a_rerun(self) -> None:
        self.assertEqual(self.world.run("0.1.0").returncode, 0)
        git("update-ref", "-d", "refs/heads/main", cwd=self.world.mirror)

        result = self.world.run("0.1.0")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.world.refs(self.world.mirror)["refs/heads/main"], self.world.split())

    def test_an_older_release_can_be_checked_after_a_newer_one(self) -> None:
        self.assertEqual(self.world.run("0.1.0").returncode, 0)
        first = self.world.head()
        core = self.world.repo / "NepalKitCore"
        (core / "Sources" / "NepalKitCore" / "Core.swift").write_text("let core = 2\n", encoding="utf-8")
        (core / "CHANGELOG.md").write_text(
            CHANGELOG.replace("## 0.1.0", "## 0.2.0 — 2026-12-01\n\n- The second.\n\n## 0.1.0"),
            encoding="utf-8")
        self.world.commit("0.2.0")
        git("push", "--quiet", "origin", "develop", cwd=self.world.repo)
        self.assertEqual(self.world.run("0.2.0").returncode, 0)

        git("checkout", "--quiet", "--detach", first, cwd=self.world.repo)
        result = self.world.run("--dry-run", "0.1.0")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("v0.1.0 is already on example/NepalKitCore; verifying it", result.stdout)

    def test_relative_signing_paths_still_sign_in_the_private_repositories(self) -> None:
        for name, source in ((".signing-key", self.world.key), (".allowed_signers", self.world.allowed_signers)):
            shutil.copy(source, self.world.repo / name)
        (self.world.repo / ".git" / "info" / "exclude").write_text(".signing-key\n.allowed_signers\n",
                                                                     encoding="utf-8")
        (self.world.repo / ".signing-key").chmod(0o600)
        git("config", "user.signingkey", ".signing-key", cwd=self.world.repo)
        git("config", "gpg.ssh.allowedSignersFile", ".allowed_signers", cwd=self.world.repo)
        result = self.world.run("--dry-run", "0.1.0")
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_the_source_tag_goes_to_every_push_url_of_origin(self) -> None:
        second = self.world.root / "second.git"
        git("init", "--quiet", "--bare", str(second), cwd=self.world.root)
        git("remote", "set-url", "--add", "--push", "origin", str(self.world.origin), cwd=self.world.repo)
        git("remote", "set-url", "--add", "--push", "origin", str(second), cwd=self.world.repo)
        self.assertEqual(self.world.run("0.1.0").returncode, 0)
        for repository in (self.world.origin, second):
            self.assertEqual(self.world.refs(repository)["refs/tags/core-v0.1.0^{}"], self.world.head())

    def test_the_mirror_push_is_atomic(self) -> None:
        # Refuse the tag alone; an atomic push must then refuse main too.
        hook = self.world.mirror / "hooks" / "update"
        hook.write_text('#!/bin/sh\ncase "$1" in refs/tags/*) exit 1 ;; esac\n', encoding="utf-8")
        hook.chmod(0o755)
        result = self.world.run("0.1.0")
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(self.world.refs(self.world.mirror), {})
        self.assertNotIn("refs/tags/core-v0.1.0", self.world.refs(self.world.origin))

    def test_no_variable_meets_a_colon_unbraced(self) -> None:
        # zsh reads "$TAG:refs/..." as $TAG with the :r modifier. Write ${TAG}:.
        code = [line.split("#", 1)[0] for line in SCRIPT.read_text(encoding="utf-8").splitlines()]
        offenders = [f"line {number}: {line.strip()}" for number, line in enumerate(code, start=1)
                     if re.search(r"\$[A-Za-z_][A-Za-z0-9_]*:[A-Za-z&]", line)]
        self.assertEqual(offenders, [])

    def test_the_expected_key_is_the_one_the_verification_guide_publishes(self) -> None:
        script = SCRIPT.read_text(encoding="utf-8")
        guide = VERIFICATION_GUIDE.read_text(encoding="utf-8")
        default = re.search(r'CORE_SIGNING_FINGERPRINT:-(SHA256:[A-Za-z0-9+/]+)', script)
        published = re.search(r"expected='(SHA256:[A-Za-z0-9+/]+)'", guide)
        self.assertIsNotNone(default)
        self.assertIsNotNone(published)
        self.assertEqual(default.group(1), published.group(1))


if __name__ == "__main__":
    unittest.main()
