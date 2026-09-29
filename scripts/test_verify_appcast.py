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
import subprocess
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
) -> str:
    parts = ["<item>", "<title>t</title>"]
    parts.append(f"<sparkle:shortVersionString>{version}</sparkle:shortVersionString>")
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


def run_verify(test: unittest.TestCase, feed: Path, plist: Path) -> str:
    buf = io.StringIO()
    with test.assertRaises(SystemExit) as ctx:
        with contextlib.redirect_stdout(buf):
            va.verify(feed, plist, None, True)
    test.assertEqual(ctx.exception.code, 1)
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
