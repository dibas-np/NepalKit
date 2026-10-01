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
    minimum_system_version: str | None = "26.6",
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


def run_cli(*args: str, cwd: str | None = None) -> subprocess.CompletedProcess:
    """Run the verifier the way CI and the release script do, as a subprocess.

    The return code is the part under test, so it has to come from the process
    boundary rather than from an in-process call.
    """
    return subprocess.run(
        [sys.executable, str(_MODULE), *args], capture_output=True, text=True, cwd=cwd
    )

def write_notes_dir(tmp: Path, notes: dict[str, str]) -> Path:
    """A scratch release-notes directory: `notes` maps version to HTML body."""
    notes_dir = tmp / "release-notes"
    notes_dir.mkdir(exist_ok=True)
    for version, body in notes.items():
        (notes_dir / f"{version}.html").write_text(body, encoding="utf-8")
    return notes_dir

def make_generated_item(version: str, description: str | None = None) -> str:
    """An item shaped the way generate_appcast writes one, newlines included.

    `make_item` is a single line, so the `(\\s*)<enclosure ` splice is only ever
    exercised against an empty whitespace group there. This one puts the
    enclosure on its own 12-space line, which is what the committed feed looks
    like, so the replacement template's indent is pinned against real input
    rather than only against a one-line fixture.
    """
    parts = [
        "        <item>\n",
        f"            <title>{version}</title>\n",
        f"            <sparkle:shortVersionString>{version}</sparkle:shortVersionString>\n",
    ]
    if description is not None:
        parts.append(f"            <description><![CDATA[\n{description}\n]]></description>\n")
    parts.append(
        f'            <enclosure url="https://example.com/NepalKit-{version}.zip" '
        f'length="1234" sparkle:edSignature="{VALID_SIGNATURE}"/>\n'
        "        </item>\n"
    )
    return "".join(parts)

def run_embed(test: unittest.TestCase, feed: Path, notes_dir: Path) -> str:
    """Call embed_notes expecting a release-stopping SystemExit; return its message.

    The message is the SystemExit's code, not 1: these two failures are
    `sys.exit(f"...")`, which puts the text on stderr, where `fail()`'s stdout
    reporting could not go. That difference is the contract, so it is asserted
    rather than flattened into an exit status.
    """
    with test.assertRaises(SystemExit) as ctx:
        with contextlib.redirect_stdout(io.StringIO()):
            va.embed_notes(feed, notes_dir)
    test.assertIsInstance(ctx.exception.code, str)
    return ctx.exception.code

def capture_embed(feed: Path, notes_dir: Path) -> str:
    """Embed for real, returning what it printed."""
    buf = io.StringIO()
    with contextlib.redirect_stdout(buf):
        va.embed_notes(feed, notes_dir)
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
        self.assertEqual(va.deployment_floor(), "26.6")
        self.assertEqual(va.deployment_floor("15.0"), "15.0")

    def test_feed_floor_must_match_the_apps_floor(self) -> None:
        # Sparkle 2.10 raised its own minimum to 12.0 and tells authors to put
        # 12.0 in the feed. On a macOS 26 app that would offer updates to
        # systems the app cannot run on, so the mismatch must stop publication.
        with tempfile.TemporaryDirectory() as tmp:
            tmp_path = Path(tmp)
            feed = write_feed(tmp_path, make_item(minimum_system_version="12.0"))
            output = run_verify(self, feed, write_plist(tmp_path), "26.6")
        self.assertIn("minimumSystemVersion is 12.0 but the app ships as 26.6", output)

    def test_matching_feed_floor_passes(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            tmp_path = Path(tmp)
            key, priv = ed25519_keypair(tmp_path)
            feed = sign_feed(tmp_path, make_item(minimum_system_version="26.6"), priv)
            output = capture_verify(feed, write_plist_with_key(tmp_path, key), "26.6")
        self.assertIn("minimumSystemVersion 26.6 matches the app's floor", output)

    def test_absent_feed_floor_is_reported_not_ignored(self) -> None:
        # An item without the element tells Sparkle nothing about the floor.
        # That is not the same as a correct value, so it must be visible.
        with tempfile.TemporaryDirectory() as tmp:
            tmp_path = Path(tmp)
            key, priv = ed25519_keypair(tmp_path)
            feed = sign_feed(tmp_path, make_item(minimum_system_version=None), priv)
            output = capture_verify(feed, write_plist_with_key(tmp_path, key), "26.6")
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

    def test_the_feed_is_signed_after_everything_that_rewrites_it(self) -> None:
        # A real release failure, not a hypothetical. Nothing in the release path
        # re-signed the feed, so generate_appcast added the new item and
        # --embed-notes rewrote the descriptions while the signature block was
        # carried forward unchanged. That is worse than an unsigned feed: it looks
        # signed while being stale, and it surfaced as a byte-count mismatch:
        #
        #   FAIL  feed signature block declares 5731 bytes of signed content but
        #   6791 bytes precede it.
        #
        # Ordering is the whole contract. sign_update signs exact bytes, so it has
        # to run after generate_appcast and after --embed-notes, and nothing may
        # write to the feed after it.
        script = (Path(__file__).resolve().parent / "verify-appcast.sh").read_text()
        generate = script.index('"$GENERATE_APPCAST" \\')
        # The invocation, not the flag: the signing block's own comment mentions
        # --embed-notes, so searching for the bare flag finds that prose first and
        # the ordering assertion silently measures a comment.
        embed = script.index('python3 "$PY" "$APPCAST" --embed-notes')
        sign = script.index('"$SIGN_UPDATE" "$APPCAST"')
        first_verify = script.index('python3 "$PY" "$APPCAST" --info-plist')

        self.assertLess(generate, sign, "the feed is signed before generate_appcast rewrites it")
        self.assertLess(embed, sign, "the feed is signed before the notes are embedded")
        self.assertLess(sign, first_verify, "the feed is verified before it is signed")

    def test_signing_is_skipped_when_the_private_key_is_absent(self) -> None:
        # CI must never hold signing material, and pages.yml runs this script
        # against the committed feed. So the absence of sign_update skips signing
        # rather than failing - and, critically, the staleness check still runs
        # afterwards, so skipping cannot hide the bug the signing step fixes.
        script = (Path(__file__).resolve().parent / "verify-appcast.sh").read_text()
        sign = script.index('"$SIGN_UPDATE" "$APPCAST"')
        conditional = script.rindex("if [[ -x \"$SIGN_UPDATE\" ]]", 0, sign)
        self.assertGreater(conditional, 0, "signing must be conditional on sign_update existing")
        self.assertIn("no sign_update", script, "the skip has to say so, not fail quietly")

    def test_the_signing_binary_is_derived_from_the_one_already_found(self) -> None:
        # SPARKLE_BIN is only set when the caller supplies it and is unset on the
        # discovery path, so "$SPARKLE_BIN/sign_update" expands to "/sign_update"
        # and silently finds nothing. Deriving from GENERATE_APPCAST cannot.
        script = (Path(__file__).resolve().parent / "verify-appcast.sh").read_text()
        self.assertIn('SIGN_UPDATE="$(dirname "$GENERATE_APPCAST")/sign_update"', script)
        self.assertNotIn('SIGN_UPDATE="$SPARKLE_BIN/sign_update"', script)

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


class EmbedNotesTest(unittest.TestCase):
    """The release-notes injection, which is a mutation and not a check.

    Every one of these used to be reachable only by running a full release: the
    logic was a heredoc inside verify-appcast.sh, so a bug in it surfaced as a
    published feed rather than as a red test. It is a different operation from
    verification - it rewrites the file, and it is what makes the verifier's own
    `<description>` contract meaningful a moment later - so it is pinned here
    rather than through the CLI's verify path.
    """

    def test_an_undescribed_item_gets_the_notes(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            tmp_path = Path(tmp)
            feed = write_feed(tmp_path, make_item(description=None, version="0.0"))
            original = feed.read_text(encoding="utf-8")
            capture_embed(feed, write_notes_dir(tmp_path, {"0.0": GOOD_NOTES}))
            out = feed.read_text(encoding="utf-8")
        self.assertIn(f"<description><![CDATA[\n{GOOD_NOTES}\n]]></description>", out)
        # Exactly one block, and removing it gives the input back byte for byte:
        # the description is the only thing this operation may change.
        inserted = f"\n            <description><![CDATA[\n{GOOD_NOTES}\n]]></description>\n            "
        self.assertEqual(out.count(inserted), 1)
        self.assertEqual(out.replace(inserted, ""), original)
        # ...and it landed where the contract says: immediately before the
        # enclosure, taking the whitespace that preceded it.
        self.assertIn(f"]]></description>\n            <enclosure ", out)

    def test_the_splice_matches_the_committed_feeds_own_indentation(self) -> None:
        # The replacement template hardcodes a 12-space indent, and the committed
        # feed's formatting depends on it: an item spliced at any other depth is
        # a feed that reads as hand-edited in the middle of a generated document.
        body = "<p>one</p>"
        with tempfile.TemporaryDirectory() as tmp:
            tmp_path = Path(tmp)
            feed = write_feed(tmp_path, make_generated_item("0.0"))
            original = feed.read_text(encoding="utf-8")
            capture_embed(feed, write_notes_dir(tmp_path, {"0.0": body}))
            out = feed.read_text(encoding="utf-8")
        self.assertIn(
            f"            <description><![CDATA[\n{body}\n]]></description>\n"
            f"            <enclosure url=",
            out,
        )
        # The 12 spaces that preceded the enclosure are consumed, not doubled.
        self.assertEqual(out.replace(f"\n            <description><![CDATA[\n{body}\n"
                                     f"]]></description>\n            <enclosure ", "\n            <enclosure "), original)

    def test_running_twice_changes_nothing_the_second_time(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            tmp_path = Path(tmp)
            feed = write_feed(tmp_path, make_item(description=None, version="0.0"))
            notes_dir = write_notes_dir(tmp_path, {"0.0": GOOD_NOTES})
            capture_embed(feed, notes_dir)
            once = feed.read_bytes()
            capture_embed(feed, notes_dir)
            twice = feed.read_bytes()
        self.assertEqual(twice, once)

    def test_an_already_described_item_is_left_alone(self) -> None:
        # Both halves of the exactly-once rule. First: a notes file exists for
        # this version and says something *different*, and the description
        # already in the feed still wins - otherwise a re-run over a published
        # feed would quietly rewrite release history. Second: an item with no
        # notes file at all is also left alone, so the early return has to come
        # before the lookup; a re-run would otherwise start failing a release the
        # moment a notes file was renamed or removed.
        with tempfile.TemporaryDirectory() as tmp:
            tmp_path = Path(tmp)
            described = write_feed(tmp_path, make_item(version="1.0"))
            # A second feed at its own path: write_feed always names feed.xml.
            undescribed = tmp_path / "undescribed.xml"
            undescribed.write_text(
                RSS_OPEN + make_item(description=None, version="1.0") + RSS_CLOSE,
                encoding="utf-8",
            )
            original = described.read_bytes()
            # A notes file for the same version saying something different.
            conflicting = write_notes_dir(tmp_path, {"1.0": "<p>SOMETHING ELSE</p>"})
            reported = capture_embed(described, conflicting)
            after = described.read_bytes()
            # Now the other half: describe it, then take its notes away and run
            # again. The second run has nothing to embed and nothing to look up.
            capture_embed(undescribed, conflicting)
            (conflicting / "1.0.html").unlink()
            capture_embed(undescribed, conflicting)
            after_undescribed = undescribed.read_bytes()
        self.assertEqual(after, original)
        self.assertNotIn(b"SOMETHING ELSE", after)
        # Described on the first run, and the second run did not add a second
        # description to it.
        self.assertEqual(after_undescribed.count(b"<description>"), 1)
        # It still says what it did. A step that silently rewrites a file about
        # to be published is the kind of absence nobody notices.
        self.assertTrue(reported.startswith("  ok    "), reported)

    def test_the_notes_file_is_trimmed_before_it_is_embedded(self) -> None:
        # Every notes file in scripts/release-notes/ ends with a newline, so
        # without the strip every release embeds a trailing blank line into the
        # description. That is invisible in the feed and shows up as a diff
        # against the committed file, so the trim is pinned here.
        body = "\n  <p>one</p>\n\n"
        with tempfile.TemporaryDirectory() as tmp:
            tmp_path = Path(tmp)
            feed = write_feed(tmp_path, make_item(description=None, version="0.0"))
            original = feed.read_text(encoding="utf-8")
            capture_embed(feed, write_notes_dir(tmp_path, {"0.0": body}))
            out = feed.read_text(encoding="utf-8")
        self.assertIn("<description><![CDATA[\n<p>one</p>\n]]></description>", out)
        self.assertEqual(out.replace(f"\n            <description><![CDATA[\n<p>one</p>\n"
                                     f"]]></description>\n            ", ""), original)

    def test_a_version_with_no_notes_file_stops_the_release(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            tmp_path = Path(tmp)
            feed = write_feed(tmp_path, make_item(description=None, version="0.0"))
            original = feed.read_bytes()
            notes_dir = write_notes_dir(tmp_path, {"9.9": GOOD_NOTES})
            message = run_embed(self, feed, notes_dir)
            self.assertIn(f"no release notes for version 0.0: expected {notes_dir / '0.0.html'}", message)
            after = feed.read_bytes()
        # The unnoted feed must not be written on the way out. An update alert
        # with no release notes is the drift; a half-written file is worse.
        self.assertEqual(after, original)

    def test_notes_containing_cdata_end_are_refused(self) -> None:
        # A `]]>` inside the body would close the CDATA block early, so the rest
        # of the fragment would be parsed as markup by every reader.
        with tempfile.TemporaryDirectory() as tmp:
            tmp_path = Path(tmp)
            feed = write_feed(tmp_path, make_item(description=None, version="0.0"))
            original = feed.read_bytes()
            notes_dir = write_notes_dir(tmp_path, {"0.0": "<p>a]]>b</p>"})
            message = run_embed(self, feed, notes_dir)
            self.assertIn("0.0.html: contains ]]>", message)
            self.assertIn("corrupt the feed", message)
            after = feed.read_bytes()
        self.assertEqual(after, original)

    def test_one_missing_file_aborts_the_whole_pass_without_writing(self) -> None:
        # The first item has notes and the second does not. The injection is
        # built entirely in memory and written once at the end, so the item that
        # could be described is *not* persisted: a partial embed would publish a
        # feed with a silent hole in it, which is strictly worse than a release
        # that stopped.
        with tempfile.TemporaryDirectory() as tmp:
            tmp_path = Path(tmp)
            feed = write_feed(
                tmp_path,
                make_item(description=None, version="0.0")
                + make_item(description=None, version="0.1", url="https://example.com/NepalKit-0.1.zip"),
            )
            original = feed.read_bytes()
            notes_dir = write_notes_dir(tmp_path, {"0.0": GOOD_NOTES})
            message = run_embed(self, feed, notes_dir)
            self.assertIn("no release notes for version 0.1", message)
            after = feed.read_bytes()
        self.assertEqual(after, original)

    def test_the_embed_needs_no_info_plist_and_runs_no_check(self) -> None:
        # It is a mutation, not a verification: no public key, no enclosure, no
        # fetch. The cwd below holds no Info.plist, so this passes only because
        # main() short-circuits before the --info-plist existence test - and the
        # second half of the pair is the control, proving that test is still
        # there for the mode that does need it.
        with tempfile.TemporaryDirectory() as tmp:
            tmp_path = Path(tmp)
            feed = write_feed(tmp_path, make_item(description=None, version="0.0"))
            notes_dir = write_notes_dir(tmp_path, {"0.0": GOOD_NOTES})
            embedded = run_cli(str(feed), "--embed-notes", str(notes_dir), cwd=str(tmp_path))
            verify = run_cli(str(feed), "--skip-crypto", cwd=str(tmp_path))
        self.assertEqual(embedded.returncode, 0, f"{embedded.stdout}{embedded.stderr}")
        self.assertNotEqual(verify.returncode, 0)
        self.assertIn("does not exist", verify.stdout)

    def test_the_shell_delegates_the_embed_to_the_verifier(self) -> None:
        # The heredoc is gone: the same contract, in a place that has a suite.
        script = (Path(__file__).resolve().parent / "verify-appcast.sh").read_text()
        self.assertNotIn("PYEOF", script)
        self.assertIn(
            'python3 "$PY" "$APPCAST" --embed-notes "${0:A:h}/release-notes"', script
        )
        # Still before the verification loop, and still its own top-level step:
        # under `set -e` a non-zero exit here has to stop the release, and an
        # `|| STATUS=1` swallow would let an unnoted feed through to publication.
        embed_at = script.index('--embed-notes "${0:A:h}/release-notes"')
        verify_at = script.index('--enclosure "$archive"')
        self.assertLess(embed_at, verify_at)
        line = script[:embed_at].rsplit("\n", 1)[-1]
        self.assertTrue(line.startswith("python3 "), f"embed call is not a bare command: {line!r}")


class FeedHistory(unittest.TestCase):
    def test_generation_preserves_the_newest_five_releases(self) -> None:
        source = (Path(__file__).resolve().parent / "verify-appcast.sh").read_text()
        command = re.search(r'^"\$GENERATE_APPCAST" \\.*?"\$ARCHIVES_DIR"', source, re.M | re.S)
        self.assertIsNotNone(command)
        with tempfile.TemporaryDirectory() as directory:
            staging = Path(directory)
            feed = staging / "appcast.xml"
            original = RSS_OPEN + "".join(make_item(version=str(version)) for version in range(6, 0, -1)) + RSS_CLOSE
            feed.write_text(original)
            generator = staging / "generate_appcast"
            generator.write_text(
                '#!/usr/bin/env python3\n'
                'import sys\nfrom pathlib import Path\n'
                'feed = Path(sys.argv[-1]) / "appcast.xml"\n'
                'limit = int(sys.argv[sys.argv.index("--maximum-versions") + 1]) if "--maximum-versions" in sys.argv else 3\n'
                'if limit:\n'
                '    import re\n    raw = feed.read_text()\n'
                '    items = re.findall(r"<item>.*?</item>", raw, re.S)\n'
                '    for item in items[limit:]: raw = raw.replace(item, "")\n'
                '    feed.write_text(raw)\n'
            )
            generator.chmod(0o755)
            result = subprocess.run(
                ["/bin/sh", "-c", command.group()],
                env={**os.environ, "GENERATE_APPCAST": str(generator), "ARCHIVES_DIR": str(staging),
                     "URL_PREFIX": "https://example.com/v6/", "RELEASE_LINK": "https://example.com/v6"},
                capture_output=True, text=True,
            )
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            expected = RSS_OPEN + "".join(make_item(version=str(version)) for version in range(6, 1, -1)) + RSS_CLOSE
            self.assertEqual(feed.read_text(), expected, "generation must retain the five newest release records")


if __name__ == "__main__":
    unittest.main()
