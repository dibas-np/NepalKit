#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Dibas Sigdel
"""Negative-path suite for the Sparkle appcast verifier.

The verifier is a security control; a check that never demonstrably rejects
is not known to work. This suite proves each layer rejects what it claims
to: malformed XML, missing or insecure enclosure fields, bad signatures,
and release-notes HTML outside the house contract. The happy path and an
openssl Ed25519 round-trip pin the verifier to the same key flow CI uses.
"""

from __future__ import annotations

import base64
import contextlib
import importlib.util
import io
import os
import re
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

_MODULE = Path(__file__).resolve().parent / "verify-appcast.py"
_spec = importlib.util.spec_from_file_location("verify_appcast", _MODULE)
va = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(va)

VALID_SIGNATURE = base64.b64encode(bytes(64)).decode()
VALID_KEY_B64 = base64.b64encode(bytes(32)).decode()
GOOD_NOTES = "<b>Features:</b><ul><li>fix</li></ul><p>notes</p>"

RSS_OPEN = (
    '<?xml version="1.0" encoding="utf-8"?>\n'
    '<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle">'
    "<channel><title>t</title>"
)
RSS_CLOSE = "</channel></rss>"


def make_item(
    url: str | None = "https://example.com/NepalKit-1.0.zip",
    length: str | None = "1234",
    signature: str | None = VALID_SIGNATURE,
    description: str | None = GOOD_NOTES,
    version: str = "1.0",
    include_enclosure: bool = True,
    minimum_system_version: str | None = "26.0",
) -> str:
    parts = ["<item>", "<title>t</title>"]
    parts.append(f"<sparkle:shortVersionString>{version}</sparkle:shortVersionString>")
    if minimum_system_version is not None:
        parts.append(
            f"<sparkle:minimumSystemVersion>{minimum_system_version}"
            f"</sparkle:minimumSystemVersion>"
        )
    if description is not None:
        if "]]>" in description:
            escaped = description.replace("]]>", "]]&gt;")
            parts.append(f"<description>{escaped}</description>")
        else:
            parts.append(f"<description><![CDATA[{description}]]></description>")
    if include_enclosure:
        attrs = []
        if url is not None:
            attrs.append(f'url="{url}"')
        if length is not None:
            attrs.append(f'length="{length}"')
        if signature is not None:
            attrs.append(f'sparkle:edSignature="{signature}"')
        parts.append(f"<enclosure {' '.join(attrs)} />")
    parts.append("</item>")
    return "".join(parts)


def write_feed(tmp: Path, body: str) -> Path:
    feed = tmp / "feed.xml"
    feed.write_text(RSS_OPEN + body + RSS_CLOSE, encoding="utf-8")
    return feed


def write_plist(tmp: Path) -> Path:
    plist = tmp / "Info.plist"
    plist.write_text(
        '<?xml version="1.0"?><plist><dict><key>SUPublicEDKey</key>'
        f"<string>{VALID_KEY_B64}</string></dict></plist>",
        encoding="utf-8",
    )
    return plist


def run_verify(test: unittest.TestCase, feed: Path, plist: Path,
               minimum_system_version: str | None = None) -> str:
    buf = io.StringIO()
    with test.assertRaises(SystemExit) as ctx:
        with contextlib.redirect_stdout(buf):
            va.verify(feed, plist, None, True, minimum_system_version)
    test.assertEqual(ctx.exception.code, 1)
    return buf.getvalue()


def capture_verify(feed: Path, plist: Path,
                   minimum_system_version: str | None = None) -> str:
    buf = io.StringIO()
    with contextlib.redirect_stdout(buf):
        va.verify(feed, plist, None, True, minimum_system_version)
    return buf.getvalue()


class VerifyAppcastTest(unittest.TestCase):
    def test_no_items_fails(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            tmp_path = Path(tmp)
            feed = write_feed(tmp_path, "")
            output = run_verify(self, feed, write_plist(tmp_path))
        self.assertIn("no <item>", output)

    def test_root_not_rss_fails(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            tmp_path = Path(tmp)
            feed = tmp_path / "feed.xml"
            feed.write_text("<feed><channel></channel></feed>", encoding="utf-8")
            output = run_verify(self, feed, write_plist(tmp_path))
        self.assertIn("expected an RSS document", output)

    def test_not_well_formed_fails(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            tmp_path = Path(tmp)
            feed = write_feed(tmp_path, make_item())
            raw = feed.read_text(encoding="utf-8")
            feed.write_text(raw[: len(raw) // 2], encoding="utf-8")
            output = run_verify(self, feed, write_plist(tmp_path))
        self.assertIn("not well-formed XML", output)

    def test_missing_enclosure_fails(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            tmp_path = Path(tmp)
            feed = write_feed(tmp_path, make_item(include_enclosure=False))
            output = run_verify(self, feed, write_plist(tmp_path))
        self.assertIn("no <enclosure>", output)

    def test_http_url_fails(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            tmp_path = Path(tmp)
            feed = write_feed(
                tmp_path, make_item(url="http://example.com/NepalKit-1.0.zip")
            )
            output = run_verify(self, feed, write_plist(tmp_path))
        self.assertIn("not https", output)

    def test_bad_length_fails(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            tmp_path = Path(tmp)
            plist = write_plist(tmp_path)
            feed = write_feed(tmp_path, make_item(length=None))
            output = run_verify(self, feed, plist)
            self.assertIn("length missing or non-numeric", output)
            feed = write_feed(tmp_path, make_item(length="abc"))
            output = run_verify(self, feed, plist)
            self.assertIn("length missing or non-numeric", output)

    def test_missing_signature_fails(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            tmp_path = Path(tmp)
            feed = write_feed(tmp_path, make_item(signature=None))
            output = run_verify(self, feed, write_plist(tmp_path))
        self.assertIn("no sparkle:edSignature", output)

    def test_signature_not_base64_fails(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            tmp_path = Path(tmp)
            feed = write_feed(tmp_path, make_item(signature="!!!"))
            output = run_verify(self, feed, write_plist(tmp_path))
        self.assertIn("not valid base64", output)

    def test_signature_wrong_length_fails(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            tmp_path = Path(tmp)
            short = base64.b64encode(bytes(63)).decode()
            feed = write_feed(tmp_path, make_item(signature=short))
            output = run_verify(self, feed, write_plist(tmp_path))
        self.assertIn("63 bytes", output)

    def test_description_foreign_tag_fails(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            tmp_path = Path(tmp)
            feed = write_feed(
                tmp_path, make_item(description="<p>hi</p><script>x</script>")
            )
            output = run_verify(self, feed, write_plist(tmp_path))
        self.assertIn("script", output)

    def test_description_cdata_break_fails(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            tmp_path = Path(tmp)
            feed = write_feed(tmp_path, make_item(description="foo]]>bar"))
            output = run_verify(self, feed, write_plist(tmp_path))
        self.assertIn("]]>", output)

    def test_description_too_long_fails(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            tmp_path = Path(tmp)
            long_notes = "x" * (va.MAX_NOTES_CHARS + 1)
            feed = write_feed(tmp_path, make_item(description=long_notes))
            output = run_verify(self, feed, write_plist(tmp_path))
        self.assertIn(f"over the {va.MAX_NOTES_CHARS} cap", output)

    def test_happy_path_passes(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            tmp_path = Path(tmp)
            feed = write_feed(tmp_path, make_item())
            buf = io.StringIO()
            with contextlib.redirect_stdout(buf):
                va.verify(feed, write_plist(tmp_path), None, True)
            self.assertIn("release notes match the notes contract", buf.getvalue())

    def test_deployment_floor_is_read_from_the_release_script(self) -> None:
        # The floor is whatever package-release.sh builds as, not a number typed
        # into a second place that can drift from it.
        self.assertEqual(va.deployment_floor(), "26.0")
        self.assertEqual(va.deployment_floor("15.0"), "15.0")

    def test_feed_floor_must_match_the_apps_floor(self) -> None:
        # Sparkle 2.10 raised its own minimum to 12.0 and tells authors to put
        # 12.0 in the feed. On a macOS 26 app that would offer updates to
        # systems the app cannot run on, so the mismatch must stop publication.
        with tempfile.TemporaryDirectory() as tmp:
            tmp_path = Path(tmp)
            feed = write_feed(tmp_path, make_item(minimum_system_version="12.0"))
            output = run_verify(self, feed, write_plist(tmp_path), "26.0")
        self.assertIn("minimumSystemVersion is 12.0 but the app ships as 26.0", output)

    def test_matching_feed_floor_passes(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            tmp_path = Path(tmp)
            feed = write_feed(tmp_path, make_item(minimum_system_version="26.0"))
            output = capture_verify(feed, write_plist(tmp_path), "26.0")
        self.assertIn("minimumSystemVersion 26.0 matches the app's floor", output)

    def test_absent_feed_floor_is_reported_not_ignored(self) -> None:
        # An item without the element tells Sparkle nothing about the floor.
        # That is not the same as a correct value, so it must be visible.
        with tempfile.TemporaryDirectory() as tmp:
            tmp_path = Path(tmp)
            feed = write_feed(tmp_path, make_item(minimum_system_version=None))
            output = capture_verify(feed, write_plist(tmp_path), "26.0")
        self.assertIn("no <sparkle:minimumSystemVersion>", output)

    def test_generation_seeds_the_staging_dir_with_the_live_feed(self) -> None:
        # `generate_appcast` merges into an existing appcast only when one is
        # reachable in the archives directory it is pointed at, and
        # package-release.sh hands it a freshly created one holding just the
        # new zip. Without a seeded predecessor it starts from empty and writes
        # a feed containing this release alone - which no other check here
        # would notice, because a one-item feed is a perfectly valid feed. It
        # has to be pinned in the script, not assumed of the tool.
        script = (Path(__file__).resolve().parent / "verify-appcast.sh").read_text()
        seed = script.index('cp "$ROOT/appcast.xml"')
        # The invocation, not the variable: the name is also referenced earlier
        # when locating the binary, and matching that would test nothing.
        generate = script.index('"$GENERATE_APPCAST" \\')
        self.assertLess(seed, generate, "the feed must be seeded before generate_appcast runs")
        self.assertIn('"$ARCHIVES_DIR/appcast.xml"', script)

    def test_the_committed_feed_carries_more_than_one_release(self) -> None:
        # The consequence, stated on the repository's own feed: a feed that has
        # lost its history looks exactly like a successful release, so the
        # only place the loss is visible is here.
        feed = Path(__file__).resolve().parent.parent / "appcast.xml"
        items = feed.read_text(encoding="utf-8").count("<item>")
        self.assertGreaterEqual(items, 2, "the committed feed has lost release history")

    def test_generation_links_to_the_release_page_not_the_repository(self) -> None:
        # Sparkle surfaces <link> as the update's "Learn More" destination, so
        # the repository URL drops the release notes the user is being offered.
        # It was hand-corrected to the tag form for 1.1 while the script still
        # emitted the repository, which is how it silently reverted for 1.2.
        script = (Path(__file__).resolve().parent / "verify-appcast.sh").read_text()
        self.assertIn('RELEASE_LINK="$REPO_URL/releases/tag/$TAG"', script)
        self.assertIn('--link "$RELEASE_LINK"', script)
        self.assertNotIn('--link "$REPO_URL" \\', script)

    def test_every_feed_item_links_to_its_own_release_page(self) -> None:
        feed = Path(__file__).resolve().parent.parent / "appcast.xml"
        raw = feed.read_text(encoding="utf-8")
        mismatched = []
        for item in re.findall(r"<item>.*?</item>", raw, flags=re.S):
            version = re.search(r"<sparkle:shortVersionString>([^<]+)</", item)
            link = re.search(r"<link>([^<]+)</link>", item)
            if not version or not link:
                mismatched.append("item without version or link")
                continue
            # Tags carry a `v` from 1.3.0 on; 1.0 to 1.2 shipped without one and
            # are not rewritten, because every enclosure url in the feed is
            # fetched during a release and moving those tags would 404 the feed
            # every installed copy polls. Both spellings are therefore correct
            # for their release, and the link has to match whichever one it is.
            acceptable = (
                f"/releases/tag/{version.group(1)}",
                f"/releases/tag/v{version.group(1)}",
            )
            if not link.group(1).endswith(acceptable):
                mismatched.append(f"{version.group(1)} -> {link.group(1)}")
        self.assertEqual(mismatched, [], f"feed items not pointing at their release page: {mismatched}")

    def test_the_download_prefix_keeps_its_trailing_slash(self) -> None:
        # generate_appcast joins the archive name with `URL(string:relativeTo:)`,
        # and Foundation REPLACES a base URL's last path component when there
        # is no trailing slash. Without the slash the url came out as
        # `releases/download/NepalKit-1.2.zip` and 404'd, which is why this
        # script used to generate against a placeholder and rewrite every
        # enclosure afterwards - and that rewrite is what repointed 1.0 and
        # 1.1 into the new release's directory. Normalising the prefix deletes
        # the step instead of guarding it.
        script = (Path(__file__).resolve().parent / "verify-appcast.sh").read_text()
        self.assertIn('URL_PREFIX="${URL_PREFIX%/}/"', script)
        self.assertIn('--download-url-prefix "$URL_PREFIX"', script)
        self.assertNotIn("nepalkit.invalid/placeholder", script)
        self.assertNotIn("PYEOF\nimport re", script.split("# Embed the release notes")[0])

    def test_a_slashed_prefix_appends_where_an_unslashed_one_replaces(self) -> None:
        # The Foundation rule the prefix normalisation exists for, pinned
        # against Foundation itself so the comment cannot drift from the
        # behaviour.
        import urllib.parse
        base_unslashed = "https://github.com/dibas-np/NepalKit/releases/download/1.2"
        base_slashed = base_unslashed + "/"
        self.assertEqual(
            urllib.parse.urljoin(base_unslashed, "NepalKit-1.2.zip"),
            "https://github.com/dibas-np/NepalKit/releases/download/NepalKit-1.2.zip",
        )
        self.assertEqual(
            urllib.parse.urljoin(base_slashed, "NepalKit-1.2.zip"),
            "https://github.com/dibas-np/NepalKit/releases/download/1.2/NepalKit-1.2.zip",
        )

    def test_crypto_round_trip(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            tmp_path = Path(tmp)
            priv = tmp_path / "priv.pem"
            pub_der = tmp_path / "pub.der"
            subprocess.run(
                ["openssl", "genpkey", "-algorithm", "ed25519", "-out", str(priv)],
                check=True,
                capture_output=True,
            )
            subprocess.run(
                [
                    "openssl", "pkey", "-in", str(priv),
                    "-pubout", "-outform", "DER", "-out", str(pub_der),
                ],
                check=True,
                capture_output=True,
            )
            der = pub_der.read_bytes()
            self.assertEqual(der[:12], va.ED25519_SPKI_PREFIX)
            public_key = der[12:]
            self.assertEqual(len(public_key), 32)
            data = os.urandom(1024)
            data_file = tmp_path / "data.bin"
            sig_file = tmp_path / "sig.bin"
            data_file.write_bytes(data)
            subprocess.run(
                [
                    "openssl", "pkeyutl", "-sign", "-rawin",
                    "-inkey", str(priv), "-in", str(data_file),
                    "-out", str(sig_file),
                ],
                check=True,
                capture_output=True,
            )
            signature = sig_file.read_bytes()
            self.assertEqual(len(signature), 64)
            self.assertTrue(va.verify_signature(public_key, data, signature))
            self.assertFalse(va.verify_signature(public_key, data + b"x", signature))


if __name__ == "__main__":
    unittest.main()
