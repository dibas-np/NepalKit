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


def write_plist_with_key(tmp: Path, key_b64: str) -> Path:
    """An Info.plist carrying a specific SUPublicEDKey."""
    plist = tmp / "keyed-Info.plist"
    plist.write_text(
        '<?xml version="1.0"?><plist><dict><key>SUPublicEDKey</key>'
        f"<string>{key_b64}</string></dict></plist>",
        encoding="utf-8",
    )
    return plist


# --- Feed signing fixtures -------------------------------------------------
# The feed signature has to be made with a real key, so these build a throwaway
# Ed25519 pair with the same openssl the verifier checks with. Nothing here
# touches a keychain or a private key belonging to the project.
#
# One case cannot be built this way: proof that the verifier agrees with the
# *tool* about which bytes are signed. A verifier tested only against
# signatures it produced itself agrees with its own assumptions by
# construction. GOLDEN_SIGNED_FEED below is the real output of Sparkle's own
# `sign_update`, captured verbatim, and is checked against the throwaway
# public key that signed it - so the format is pinned to what Sparkle
# actually writes rather than to what this file believes Sparkle writes.
GOLDEN_SIGNED_FEED_B64 = (
    "PD94bWwgdmVyc2lvbj0iMS4wIiBzdGFuZGFsb25lPSJ5ZXMiPz4KPHJzcyB4bWxuczpzcGFya2xl"
    "PSJodHRwOi8vd3d3LmFuZHltYXR1c2NoYWsub3JnL3htbC1uYW1lc3BhY2VzL3NwYXJrbGUiIHZl"
    "cnNpb249IjIuMCI+CiAgICA8Y2hhbm5lbD4KICAgICAgICA8dGl0bGU+UHJvYmVBcHA8L3RpdGxl"
    "PgogICAgICAgIDxpdGVtPgogICAgICAgICAgICA8dGl0bGU+Mi4wPC90aXRsZT4KICAgICAgICAg"
    "ICAgPHB1YkRhdGU+V2VkLCAzMCBTZXAgMjAyNiAxNDo0Mzo1MSArMDU0NTwvcHViRGF0ZT4KICAg"
    "ICAgICAgICAgPGxpbms+aHR0cHM6Ly9leGFtcGxlLmNvbTwvbGluaz4KICAgICAgICAgICAgPHNw"
    "YXJrbGU6dmVyc2lvbj4yMDA8L3NwYXJrbGU6dmVyc2lvbj4KICAgICAgICAgICAgPHNwYXJrbGU6"
    "c2hvcnRWZXJzaW9uU3RyaW5nPjIuMDwvc3BhcmtsZTpzaG9ydFZlcnNpb25TdHJpbmc+CiAgICAg"
    "ICAgICAgIDxzcGFya2xlOm1pbmltdW1TeXN0ZW1WZXJzaW9uPjI2LjA8L3NwYXJrbGU6bWluaW11"
    "bVN5c3RlbVZlcnNpb24+CiAgICAgICAgICAgIDxlbmNsb3N1cmUgdXJsPSJodHRwczovL2V4YW1w"
    "bGUuY29tL2RsL3YyLjAvUHJvYmVBcHAtMi4wLnppcCIgbGVuZ3RoPSIyODkyIiB0eXBlPSJhcHBs"
    "aWNhdGlvbi9vY3RldC1zdHJlYW0iLz4KICAgICAgICA8L2l0ZW0+CiAgICA8L2NoYW5uZWw+Cjwv"
    "cnNzPjwhLS0gc3BhcmtsZS1zaWduYXR1cmVzOgplZFNpZ25hdHVyZTogdGNKY0JEUHl4cUozNmVz"
    "aHlxWmlLdTU2MmpiN0JRUDFhV3J6Sno4SksrMGxqUUFiNWtPcGM5Lzh3QmNmQ2w1MG1WSGlVakZI"
    "RGplTmhSeXpDSzRoQVE9PQpsZW5ndGg6IDY4OAotLT4K"
)
GOLDEN_SIGNED_FEED_KEY_B64 = "y9S6PPgQ+ObSuKALymgxuJ5vFxP3qjQOgb5Qmh7aBAc="


def ed25519_keypair(tmp: Path, name: str = "feed") -> tuple[str, Path]:
    """Return (public key base64, private key PEM path) for a throwaway key."""
    priv = tmp / f"{name}-priv.pem"
    pub_der = tmp / f"{name}-pub.der"
    subprocess.run(
        ["openssl", "genpkey", "-algorithm", "ed25519", "-out", str(priv)],
        check=True, capture_output=True,
    )
    subprocess.run(
        ["openssl", "pkey", "-in", str(priv), "-pubout", "-outform", "DER",
         "-out", str(pub_der)],
        check=True, capture_output=True,
    )
    der = pub_der.read_bytes()
    assert der[:12] == va.ED25519_SPKI_PREFIX, "unexpected SubjectPublicKeyInfo"
    return base64.b64encode(der[12:]).decode(), priv


def ed25519_sign(priv: Path, tmp: Path, data: bytes) -> bytes:
    data_file = tmp / "to-sign.bin"
    sig_file = tmp / "made-signature.bin"
    data_file.write_bytes(data)
    subprocess.run(
        ["openssl", "pkeyutl", "-sign", "-rawin", "-inkey", str(priv),
         "-in", str(data_file), "-out", str(sig_file)],
        check=True, capture_output=True,
    )
    return sig_file.read_bytes()


def sign_feed(tmp: Path, body: str, priv: Path, *, signature: bytes | None = None,
              sign: bool = True, declared_length: int | None = None,
              name: str = "signed-feed.xml") -> Path:
    """Write `body` as a feed, signed the way sign_update signs one.

    `signature` overrides the real signature (for the malformed cases);
    `sign=False` leaves the block off entirely; `declared_length` overrides the
    byte count written into the block.
    """
    content = (RSS_OPEN + body + RSS_CLOSE).encode("utf-8")
    if not sign:
        path = tmp / name
        path.write_bytes(content)
        return path
    sig = ed25519_sign(priv, tmp, content) if signature is None else signature
    block = (
        f"<!-- sparkle-signatures:\n"
        f"edSignature: {base64.b64encode(sig).decode()}\n"
        f"length: {len(content) if declared_length is None else declared_length}\n"
        f"-->\n"
    )
    path = tmp / name
    path.write_bytes(content + block.encode("utf-8"))
    return path


def run_verify(test: unittest.TestCase, feed: Path, plist: Path,
               minimum_system_version: str | None = None) -> str:
    buf = io.StringIO()
    with test.assertRaises(SystemExit) as ctx:
        with contextlib.redirect_stdout(buf):
            va.verify(feed, plist, None, True, minimum_system_version)
    test.assertEqual(ctx.exception.code, 1)
    return buf.getvalue()


def capture_verify(feed: Path, plist: Path,
                   minimum_system_version: str | None = None,
                   enclosure: Path | None = None) -> str:
    """Run `verify` in-process and return what it printed.

    With an `enclosure` the byte and signature layers really run. Without one it
    passes `skip_crypto`, which since plan 022 is a *reported skip* rather than
    a pass — so a caller using this form is asserting a run that did not fully
    verify, and the output says so.
    """
    buf = io.StringIO()
    with contextlib.redirect_stdout(buf):
        va.verify(feed, plist, enclosure, enclosure is None, minimum_system_version)
    return buf.getvalue()


def run_cli(*args: str) -> subprocess.CompletedProcess:
    """Run the verifier the way CI and the release script do, as a subprocess.

    The return code is the part under test, so it has to come from the process
    boundary rather than from an in-process call.
    """
    return subprocess.run(
        [sys.executable, str(_MODULE), *args], capture_output=True, text=True
    )

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
            # A signed feed, because the signature is now part of the happy
            # path: reaching the end of verify() requires one.
            key, priv = ed25519_keypair(tmp_path)
            feed = sign_feed(tmp_path, make_item(), priv)
            buf = io.StringIO()
            with contextlib.redirect_stdout(buf):
                va.verify(feed, write_plist_with_key(tmp_path, key), None, True)
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
            key, priv = ed25519_keypair(tmp_path)
            feed = sign_feed(tmp_path, make_item(minimum_system_version="26.0"), priv)
            output = capture_verify(feed, write_plist_with_key(tmp_path, key), "26.0")
        self.assertIn("minimumSystemVersion 26.0 matches the app's floor", output)

    def test_absent_feed_floor_is_reported_not_ignored(self) -> None:
        # An item without the element tells Sparkle nothing about the floor.
        # That is not the same as a correct value, so it must be visible.
        with tempfile.TemporaryDirectory() as tmp:
            tmp_path = Path(tmp)
            key, priv = ed25519_keypair(tmp_path)
            feed = sign_feed(tmp_path, make_item(minimum_system_version=None), priv)
            output = capture_verify(feed, write_plist_with_key(tmp_path, key), "26.0")
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


    def test_a_skipped_item_fails_the_run(self) -> None:
        # An item whose bytes were never looked at is not an item that passed.
        # This run checks structure and nothing else, and it has to say so in
        # the exit code: the old code printed a skip line and then "Appcast is
        # sound." and returned 0, which is how CI stayed green having verified
        # no item in the feed at all.
        with tempfile.TemporaryDirectory() as tmp:
            tmp_path = Path(tmp)
            key_b64, priv = ed25519_keypair(tmp_path, "skipped")
            feed = sign_feed(tmp_path, make_item(), priv)
            result = run_cli(str(feed), "--info-plist", str(write_plist_with_key(tmp_path, key_b64)),
                             "--skip-crypto")
        self.assertNotEqual(result.returncode, 0, f"a skipped item passed:\n{result.stdout}")
        self.assertIn("Appcast NOT verified", result.stdout)
        # The version is named, not just counted: a reader has to know which.
        self.assertIn("1.0", result.stdout.split("Appcast NOT verified", 1)[1])

    def test_a_fully_verified_item_still_passes(self) -> None:
        # The other half of the pair above: an item whose real bytes are on
        # disk and correctly signed clears every layer and is reported sound.
        with tempfile.TemporaryDirectory() as tmp:
            tmp_path = Path(tmp)
            payload = b"the real bytes of the archive"
            archive = tmp_path / "NepalKit-1.0.zip"
            archive.write_bytes(payload)
            key_b64, priv = ed25519_keypair(tmp_path, "release")
            signature = base64.b64encode(ed25519_sign(priv, tmp_path, payload)).decode()
            feed = sign_feed(tmp_path, make_item(length=str(len(payload)), signature=signature), priv)
            result = run_cli(str(feed), "--info-plist", str(write_plist_with_key(tmp_path, key_b64)),
                             "--enclosure", str(archive))
        self.assertEqual(result.returncode, 0, result.stdout)
        self.assertIn("enclosure length matches", result.stdout)
        self.assertIn("signature verifies against the committed public key", result.stdout)
        self.assertIn("Appcast is sound.", result.stdout)

    def test_a_skipped_item_never_reports_the_appcast_as_sound(self) -> None:
        # The precise regression: the old code printed the skip line *and* the
        # success line in the same run, so a log reader saw a clean pass.
        with tempfile.TemporaryDirectory() as tmp:
            tmp_path = Path(tmp)
            key_b64, priv = ed25519_keypair(tmp_path, "skipped")
            feed = sign_feed(tmp_path, make_item(), priv)
            result = run_cli(str(feed), "--info-plist", str(write_plist_with_key(tmp_path, key_b64)),
                             "--skip-crypto")
        self.assertNotIn("Appcast is sound.", result.stdout)
        # The skip line itself stays. The information was useful; it was the
        # conclusion drawn from it that was wrong.
        self.assertIn("skip  version 1.0: no enclosure bytes available to verify", result.stdout)

    def test_a_partial_release_run_is_named_but_does_not_fail(self) -> None:
        # The release-time shape: the feed keeps every release ever published
        # while the staging directory holds one archive, so every other item has
        # no bytes to check. That gap is documented and expected, and blocking
        # a release on it would be wrong - but it has to be named, and the
        # default (no --allow-partial) still refuses to call it a pass.
        with tempfile.TemporaryDirectory() as tmp:
            tmp_path = Path(tmp)
            payload = b"the real bytes of the archive"
            archive = tmp_path / "NepalKit-1.1.zip"
            archive.write_bytes(payload)
            key_b64, priv = ed25519_keypair(tmp_path, "partial")
            signature = base64.b64encode(ed25519_sign(priv, tmp_path, payload)).decode()
            plist = write_plist_with_key(tmp_path, key_b64)
            feed = sign_feed(
                tmp_path,
                make_item(url="https://example.com/NepalKit-1.1.zip", version="1.1",
                          length=str(len(payload)), signature=signature)
                + make_item(version="1.0", length="1234", signature=signature),
                priv,
            )
            partial = run_cli(str(feed), "--info-plist", str(plist),
                              "--enclosure", str(archive), "--allow-partial")
            default = run_cli(str(feed), "--info-plist", str(plist),
                              "--enclosure", str(archive))
        # The staged item is checked for real, in both runs.
        for result in (partial, default):
            self.assertIn("signature verifies against the committed public key", result.stdout)
            self.assertIn("1.0", result.stdout.split("Appcast NOT verified", 1)[1])
        # Same feed, same skip; only the policy differs.
        self.assertEqual(partial.returncode, 0, partial.stdout)
        self.assertNotEqual(default.returncode, 0, default.stdout)

class FeedSignatureTest(unittest.TestCase):
    """The feed's own signature, as distinct from the archives'.

    A signed archive proves the download was not swapped. It says nothing about
    whether the feed lied about that download, so the feed is signed too, and
    these pin that layer separately from the enclosure one - including that the
    two are independent and that adding the feed check did not replace anything.
    """

    def test_signed_feed_passes(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            tmp_path = Path(tmp)
            payload = b"the bytes the enclosure check will read"
            archive = tmp_path / "NepalKit-1.0.zip"
            archive.write_bytes(payload)
            key, priv = ed25519_keypair(tmp_path)
            signature = base64.b64encode(ed25519_sign(priv, tmp_path, payload)).decode()
            feed = sign_feed(
                tmp_path, make_item(length=str(len(payload)), signature=signature), priv)
            output = capture_verify(feed, write_plist_with_key(tmp_path, key),
                                    enclosure=archive)
        self.assertIn("enclosure length matches", output)
        self.assertIn("feed signature verifies against the committed public key",
                      output)
        # Every layer ran and every one of them passed, so the run is a pass.
        # With no enclosure the item would be a reported skip, and 022 made that
        # a non-zero exit - which would make this test assert a run that cannot
        # reach "Appcast is sound." at all.
        self.assertIn("Appcast is sound.", output)

    def test_unsigned_feed_fails(self) -> None:
        # The gap this plan exists to close: a feed with three perfectly good
        # archive signatures and no signature of its own used to pass every
        # check in the repository and still be the published feed.
        with tempfile.TemporaryDirectory() as tmp:
            tmp_path = Path(tmp)
            feed = write_feed(tmp_path, make_item())
            output = run_verify(self, feed, write_plist(tmp_path))
        self.assertIn("the feed is not signed", output)
        self.assertIn("sign_update", output)

    def test_wrong_feed_signature_fails(self) -> None:
        # Signed, but over something else - the case a feed edited in transit
        # produces. A check that only asked "is there a block here" would pass.
        with tempfile.TemporaryDirectory() as tmp:
            tmp_path = Path(tmp)
            key, priv = ed25519_keypair(tmp_path)
            wrong = ed25519_sign(priv, tmp_path, b"a different document")
            feed = sign_feed(tmp_path, make_item(), priv, signature=wrong)
            output = run_verify(self, feed, write_plist_with_key(tmp_path, key))
        self.assertIn("feed signature does NOT verify", output)

    def test_feed_signature_from_a_different_key_fails(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            tmp_path = Path(tmp)
            _signing_key, priv = ed25519_keypair(tmp_path, "signer")
            other_key, _ = ed25519_keypair(tmp_path, "other")
            self.assertNotEqual(_signing_key, other_key)
            feed = sign_feed(tmp_path, make_item(), priv)
            output = run_verify(self, feed, write_plist_with_key(tmp_path, other_key))
        self.assertIn("feed signature does NOT verify", output)

    def test_tampered_version_string_fails(self) -> None:
        # The threat ADR-0012 describes, made mechanical: a feed whose signature
        # is valid, edited to claim a different version. The signature covers
        # the item metadata, so this must not pass.
        with tempfile.TemporaryDirectory() as tmp:
            tmp_path = Path(tmp)
            key, priv = ed25519_keypair(tmp_path)
            feed = sign_feed(tmp_path, make_item(), priv)
            raw = feed.read_bytes().replace(b">1.0<", b">9.9<", 1)
            tampered = tmp_path / "tampered.xml"
            tampered.write_bytes(raw)
            output = run_verify(self, tampered, write_plist_with_key(tmp_path, key))
        self.assertIn("feed signature does NOT verify", output)

    def test_broken_enclosure_still_fails_when_the_feed_is_signed(self) -> None:
        # The new check must sit alongside the old one, not on top of it: a
        # valid feed signature does not excuse a missing archive signature.
        with tempfile.TemporaryDirectory() as tmp:
            tmp_path = Path(tmp)
            key, priv = ed25519_keypair(tmp_path)
            feed = sign_feed(tmp_path, make_item(signature=None), priv)
            output = run_verify(self, feed, write_plist_with_key(tmp_path, key))
        self.assertIn("no sparkle:edSignature", output)

    def test_feed_signature_not_base64_fails(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            tmp_path = Path(tmp)
            key, priv = ed25519_keypair(tmp_path)
            feed = sign_feed(tmp_path, make_item(), priv)
            raw = re.sub(rb"edSignature: \S+", b"edSignature: !!!", feed.read_bytes())
            broken = tmp_path / "bad-b64.xml"
            broken.write_bytes(raw)
            output = run_verify(self, broken, write_plist_with_key(tmp_path, key))
        self.assertIn("feed signature is not valid base64", output)

    def test_feed_signature_wrong_length_fails(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            tmp_path = Path(tmp)
            key, priv = ed25519_keypair(tmp_path)
            feed = sign_feed(tmp_path, make_item(), priv)
            raw = re.sub(rb"edSignature: \S+", b"edSignature: QUJD", feed.read_bytes())
            broken = tmp_path / "short-sig.xml"
            broken.write_bytes(raw)
            output = run_verify(self, broken, write_plist_with_key(tmp_path, key))
        self.assertIn("feed signature is 3 bytes, expected 64", output)

    def test_misdeclared_block_length_fails(self) -> None:
        # Sparkle only reads `length` to explain a failure, so this one would
        # not stop a client accepting the feed. It still means the block was
        # assembled by hand rather than by sign_update, which is the thing that
        # must not pass.
        with tempfile.TemporaryDirectory() as tmp:
            tmp_path = Path(tmp)
            key, priv = ed25519_keypair(tmp_path)
            feed = sign_feed(tmp_path, make_item(), priv, declared_length=1)
            output = run_verify(self, feed, write_plist_with_key(tmp_path, key))
        self.assertIn("The block was not written by sign_update", output)

    def test_unsigned_feed_fails_under_skip_crypto(self) -> None:
        # `--skip-crypto` exists because CI has no archive bytes. The feed is
        # the file under test and is present, so this layer must still fire -
        # otherwise the only job in the repository that reads the real
        # appcast.xml (pages.yml) would skip the check that matters.
        with tempfile.TemporaryDirectory() as tmp:
            tmp_path = Path(tmp)
            feed = write_feed(tmp_path, make_item())
            output = run_verify(self, feed, write_plist(tmp_path))
        self.assertIn("the feed is not signed", output)

    def test_canonical_form_matches_sparkle_sign_update(self) -> None:
        # The anti-false-green case. This feed is Sparkle's own sign_update
        # output, byte for byte, and the key that signed it is gone; the public
        # half travels with the fixture. If the canonical form this file
        # computes ever drifts from the tool's, this fails - and it is the one
        # check in the suite that was not signed by the same code it tests.
        with tempfile.TemporaryDirectory() as tmp:
            tmp_path = Path(tmp)
            raw = base64.b64decode(GOLDEN_SIGNED_FEED_B64)
            feed = tmp_path / "golden.xml"
            feed.write_bytes(raw)
            content, signature_b64, declared_length = va.extract_feed_signature(raw)
            self.assertIsNotNone(signature_b64)
            self.assertEqual(len(content), declared_length)
            self.assertTrue(raw.startswith(content))
            self.assertTrue(
                va.verify_signature(
                    base64.b64decode(GOLDEN_SIGNED_FEED_KEY_B64),
                    content,
                    base64.b64decode(signature_b64),
                )
            )
            # And the whole file must not verify - that is what makes "the
            # bytes before the block" the real answer rather than a coincidence.
            self.assertFalse(
                va.verify_signature(
                    base64.b64decode(GOLDEN_SIGNED_FEED_KEY_B64),
                    raw,
                    base64.b64decode(signature_b64),
                )
            )


if __name__ == "__main__":
    unittest.main()
