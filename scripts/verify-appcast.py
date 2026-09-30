#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Dibas Sigdel
"""Verify a Sparkle appcast before it is allowed to become a public feed.

An appcast is the only thing standing between a tampered binary and an
auto-installing user, so it gets checked rather than trusted. Three layers,
each of which catches something the others cannot:

  1. Well-formedness, and the fields Sparkle actually requires. A feed missing
     an enclosure or a signature makes the app silently check nothing.
  2. Enclosure consistency: `length` must equal the real byte count of the
     downloaded file. This is what stops a truncated or substituted download
     from being accepted.
  3. Cryptographic verification of the Ed25519 signature against the *committed
     public key*, using stock openssl. No private key, no keychain, so this runs
     anywhere - including CI, where the private key must never be present.
  4. The same, one level up: the *feed* is signed too. A signed archive proves
     the download was not swapped; a signed feed proves the feed did not lie
     about what the download is. See `extract_feed_signature` for the format.

Why openssl and not Sparkle's own `sign_update --verify`: verification with
sign_update needs the private key (`--ed-key-file` is rejected for public keys,
and without a key it reads the keychain). That makes it unusable in CI by
design. openssl needs only the public half, which is already committed to the
repository in Info.plist, so the same key that is baked into the shipped app is
the key CI checks against.

Exit 0 = the appcast is sound. Non-zero = it must not be published.
"""

from __future__ import annotations

import argparse
import base64
import hashlib
import re
import subprocess
import sys
import tempfile
import urllib.request
import xml.etree.ElementTree as ET
from html.parser import HTMLParser
from pathlib import Path
from urllib.parse import urlparse

SPARKLE_NS = "http://www.andymatuschak.org/xml-namespaces/sparkle"
NS = {"sparkle": SPARKLE_NS}

# The release-notes HTML contract shared with update-changelog.py's
# FragmentParser: the fragments are written by this project to exactly these
# tags. The <description> is the one part of a feed item the EdDSA signature
# does not cover — it is checked against the contract instead of trusted.
NOTES_TAGS = {"b", "li", "p", "ul"}
MAX_NOTES_CHARS = 8192


class _NotesHTMLCheck(HTMLParser):
    def __init__(self) -> None:
        super().__init__(convert_charrefs=True)
        self.offenses: list[str] = []

    def handle_starttag(self, tag, attrs):
        if tag not in NOTES_TAGS:
            self.offenses.append(f"<{tag}>")

    handle_startendtag = handle_starttag

# 12-byte DER prefix for an Ed25519 SubjectPublicKeyInfo wrapping a raw 32-byte
# key, per RFC 8410. Prepended so openssl can read the base64 key straight from
# Info.plist without a PEM round-trip.
ED25519_SPKI_PREFIX = bytes.fromhex("302a300506032b6570032100")

# --- How Sparkle signs a feed ---------------------------------------------
# Sparkle 2 does not sign the feed with an XML attribute. `sign_update` appends
# a trailing comment and signs the bytes that precede it:
#
#     <!-- sparkle-signatures:
#     edSignature: <base64 Ed25519 signature>
#     length: <byte count of the signed content>
#     -->
#
# The client splits the block off with a *backwards* search for the prefix and
# verifies the signature over everything before it (SPUExtractSignedFeed.m,
# SPUExtractAppcastContent, in the pinned Sparkle 2.9.6). So the signed content
# is the entire feed - channel element, every item, every description - minus
# that comment. It is not the channel element, and there is no
# `sparkle:dsaSignature` attribute in this Sparkle version: the DSA fields in
# it are legacy support for signing *archives*, which `SUAppcastDriver` passes
# as nil. Do not go looking for the attribute; it is not what gets written.
FEED_SIGNING_PREFIX = b"<!-- sparkle-signatures:\n"
FEED_SIGNING_SUFFIX = b"-->"


def fail(message: str) -> "NoReturn":  # type: ignore[valid-type]
    print(f"  FAIL  {message}")
    raise SystemExit(1)


def ok(message: str) -> None:
    print(f"  ok    {message}")


def load_public_key(info_plist: Path) -> bytes:
    """Read SUPublicEDKey out of Info.plist and return raw 32-byte Ed25519 key."""
    text = info_plist.read_text(encoding="utf-8")
    marker = "SUPublicEDKey</key>"
    if marker not in text:
        fail(f"{info_plist} has no SUPublicEDKey")
    tail = text.split(marker, 1)[1]
    start = tail.find("<string>")
    end = tail.find("</string>")
    if start == -1 or end == -1:
        fail("SUPublicEDKey is not wrapped in a <string> element")
    encoded = tail[start + len("<string>") : end].strip()
    try:
        key = base64.b64decode(encoded, validate=True)
    except Exception as exc:  # noqa: BLE001
        fail(f"SUPublicEDKey is not valid base64: {exc}")
    if len(key) != 32:
        fail(f"SUPublicEDKey decodes to {len(key)} bytes, expected 32 for Ed25519")
    return key


def verify_signature(public_key: bytes, data: bytes, signature: bytes) -> bool:
    """Verify an Ed25519 signature over `data` with stock openssl."""
    with tempfile.TemporaryDirectory() as tmp:
        tmp_path = Path(tmp)
        (tmp_path / "spki.der").write_bytes(ED25519_SPKI_PREFIX + public_key)
        (tmp_path / "data.bin").write_bytes(data)
        (tmp_path / "sig.bin").write_bytes(signature)
        result = subprocess.run(
            [
                "openssl", "pkeyutl", "-verify",
                "-pubin", "-inkey", str(tmp_path / "spki.der"),
                "-keyform", "DER", "-rawin",
                "-in", str(tmp_path / "data.bin"),
                "-sigfile", str(tmp_path / "sig.bin"),
            ],
            capture_output=True,
            text=True,
        )
    return result.returncode == 0


def fetch(url: str, timeout: int = 60) -> bytes:
    request = urllib.request.Request(url, headers={"User-Agent": "NepalKit-appcast-verify"})
    with urllib.request.urlopen(request, timeout=timeout) as response:
        return response.read()


def extract_feed_signature(raw: bytes) -> tuple[bytes, str | None, int | None]:
    """Split a feed's signing block off, the way Sparkle's client does.

    Returns `(content, ed_signature_base64, declared_length)`. `content` is the
    bytes the signature is computed over: everything before the block. The
    search for the block runs backwards, as Sparkle's does, so a stray earlier
    occurrence cannot move the boundary. A feed with no block yields the whole
    file as content and `None, None` - which is why the caller has to treat
    "no block" as a failure rather than as an empty signature.
    """
    start = raw.rfind(FEED_SIGNING_PREFIX)
    if start == -1:
        return raw, None, None
    end = raw.find(FEED_SIGNING_SUFFIX, start + len(FEED_SIGNING_PREFIX))
    if end == -1:
        # An unterminated block. Sparkle's extractor returns the data untouched
        # here, so there is no signature to read out of it.
        return raw, None, None
    block = raw[start + len(FEED_SIGNING_PREFIX) : end].decode("utf-8", "replace")

    signature_b64: str | None = None
    declared_length: int | None = None
    for line in block.splitlines():
        if line.startswith("edSignature:"):
            signature_b64 = line[len("edSignature:") :].strip()
        elif line.startswith("length:"):
            value = line[len("length:") :].strip()
            declared_length = int(value) if value.isdigit() else None
    return raw[:start], signature_b64, declared_length


def verify_feed_signature(appcast: Path, info_plist: Path) -> None:
    """Require the feed itself to be signed, and check the signature.

    This runs regardless of `--skip-crypto`, unlike the enclosure checks. The
    flag exists because the archives are release assets rather than repository
    files, so their bytes are unavailable in CI; it has nothing to do with the
    feed, which is the very file under test and is right here. Skipping this
    layer under `--skip-crypto` would switch off the one check that runs
    against the published feed in `.github/workflows/pages.yml`, which is the
    only place in the repository that sees the real thing.
    """
    raw = appcast.read_bytes()
    content, signature_b64, declared_length = extract_feed_signature(raw)

    if signature_b64 is None:
        fail(
            "the feed is not signed: no <!-- sparkle-signatures: --> block. The "
            "archive signatures below prove each download was not swapped, but "
            "nothing here authenticates what the feed *says* about them - "
            "sparkle:shortVersionString, sparkle:version, "
            "sparkle:minimumSystemVersion, pubDate, item order and the enclosure "
            "urls are all attacker-editable, and a feed can be rewritten to "
            "offer an update to a system the app does not run on. Sign the feed "
            "with the same EdDSA key as the archives: "
            "`sign_update appcast.xml`, as the last step after the release notes "
            "are injected, because it signs the exact bytes it is given."
        )
    try:
        signature_bytes = base64.b64decode(signature_b64, validate=True)
    except Exception as exc:  # noqa: BLE001
        fail(f"feed signature is not valid base64: {exc}")
    if len(signature_bytes) != 64:
        fail(f"feed signature is {len(signature_bytes)} bytes, expected 64")

    if declared_length is not None and declared_length != len(content):
        # Sparkle reads this only to explain a failure ("the expected content
        # length ... differs from the downloaded file length"); it verifies the
        # real bytes either way. So a mismatch here would not by itself stop a
        # client accepting the feed. It does mean the block was assembled by
        # something other than `sign_update`, which is precisely the
        # hand-fabricated-signature case this check exists to refuse.
        fail(
            f"feed signature block declares {declared_length} bytes of signed "
            f"content but {len(content)} bytes precede it. The block was not "
            f"written by sign_update; re-sign rather than editing it."
        )

    public_key = load_public_key(info_plist)
    if verify_signature(public_key, content, signature_bytes):
        ok("feed signature verifies against the committed public key "
           f"({len(content)} bytes of feed content)")
    else:
        fail(
            f"feed signature does NOT verify against the key in "
            f"{info_plist.name}. The feed has been altered since it was signed, "
            f"or was signed with a different key. Do not publish this feed."
        )


def deployment_floor(override: str | None = None) -> str | None:
    """The macOS version the app actually ships with, as a dotted string.

    Read from package-release.sh because that file's DEPLOYMENT_TARGET is the
    value passed to the build, and Info.plist cannot be used: its
    LSMinimumSystemVersion is the unexpanded $(MACOSX_DEPLOYMENT_TARGET)
    substitution, so the source tree does not record the floor anywhere.

    This matters because <sparkle:minimumSystemVersion> is what tells Sparkle
    which systems an item is for. A feed that understates the floor offers an
    update to systems the app cannot run on; one that overstates it hides the
    update from users who could run it. Sparkle 2.10 raised its own minimum to
    12.0 and tells authors to put 12.0 in the feed, so a bump can silently
    rewrite this value without anyone editing the feed by hand.
    """
    if override:
        return override
    script = Path(__file__).resolve().parent / "package-release.sh"
    try:
        text = script.read_text(encoding="utf-8")
    except OSError:
        return None
    match = re.search(r"^DEPLOYMENT_TARGET=(\S+)", text, re.M)
    return match.group(1) if match else None


def verify(appcast: Path, info_plist: Path, enclosure: Path | None, skip_crypto: bool,
           minimum_system_version: str | None = None) -> None:
    print(f"Verifying {appcast}")
    floor = deployment_floor(minimum_system_version)
    if floor:
        print(f"App deployment floor: {floor}")

    # --- 1. Well-formedness and required fields -----------------------------
    try:
        root = ET.parse(appcast).getroot()
    except ET.ParseError as exc:
        fail(f"not well-formed XML: {exc}")
    if not root.tag.endswith("rss"):
        fail(f"root element is <{root.tag}>, expected an RSS document")

    items = root.findall("./channel/item")
    if not items:
        fail("feed contains no <item>: an app checking this would see no updates at all")
    ok(f"well-formed, {len(items)} item(s)")

    for item in items:
        version = item.findtext("sparkle:shortVersionString", default="?", namespaces=NS)
        enclosure_el = item.find("enclosure")
        if enclosure_el is None:
            fail(f"version {version}: no <enclosure>; the app has nothing to download")

        url = enclosure_el.get("url")
        if not url:
            fail(f"version {version}: enclosure has no url")
        parsed = urlparse(url)
        if parsed.scheme != "https":
            # http here would let a network attacker rewrite the payload.
            fail(f"version {version}: enclosure url is not https ({url})")

        length_attr = enclosure_el.get("length")
        if not length_attr or not length_attr.isdigit():
            fail(f"version {version}: enclosure length missing or non-numeric")
        declared_length = int(length_attr)

        signature = enclosure_el.get(f"{{{SPARKLE_NS}}}edSignature")
        if not signature:
            fail(f"version {version}: no sparkle:edSignature; the app would refuse the update")
        try:
            signature_bytes = base64.b64decode(signature, validate=True)
        except Exception as exc:  # noqa: BLE001
            fail(f"version {version}: edSignature is not valid base64: {exc}")
        if len(signature_bytes) != 64:
            fail(f"version {version}: signature is {len(signature_bytes)} bytes, expected 64")

        minimum = item.findtext("sparkle:minimumSystemVersion", default=None, namespaces=NS)
        ok(f"version {version}: https url, length {declared_length}, 64-byte signature")
        if minimum is None:
            # Absent, not wrong: an item without the element tells Sparkle
            # nothing about the floor. Say so rather than passing in silence.
            print(f"  ..    version {version}: no <sparkle:minimumSystemVersion>")
        elif floor is None:
            print(f"  ..    version {version}: minimumSystemVersion {minimum} "
                  f"unchecked (no deployment floor available)")
        elif minimum != floor:
            fail(f"version {version}: minimumSystemVersion is {minimum} but the app "
                 f"ships as {floor}. The feed would offer this update to systems "
                 f"the app does not run on, or hide it from systems that do.")
        else:
            ok(f"version {version}: minimumSystemVersion {minimum} matches the app's floor")

        description = item.findtext("description")
        if description is None:
            print(f"  ..    version {version}: no <description> (notes not yet injected)")
        else:
            if "]]>" in description:
                fail(f"version {version}: description contains ]]> — the CDATA block was corrupted")
            if len(description) > MAX_NOTES_CHARS:
                fail(f"version {version}: description is {len(description)} chars, over the {MAX_NOTES_CHARS} cap")
            checker = _NotesHTMLCheck()
            checker.feed(description)
            if checker.offenses:
                fail(f"version {version}: release notes use tags outside the house contract "
                     f"({', '.join(sorted(set(checker.offenses)))}); allowed: b, li, p, ul")
            ok(f"version {version}: release notes match the notes contract ({len(description)} chars)")

        # --- 2. Enclosure bytes match the declared length -------------------
        payload: bytes | None = None
        if enclosure is not None:
            # The feed keeps one item per release ever published, while
            # verify-appcast.sh runs one invocation per archive; only the item
            # whose enclosure names this file can be checked against it.
            if Path(parsed.path).name == enclosure.name:
                payload = enclosure.read_bytes()
        elif not skip_crypto:
            print(f"  ..    fetching {url}")
            try:
                payload = fetch(url)
            except Exception as exc:  # noqa: BLE001
                fail(f"version {version}: could not fetch enclosure: {exc}")

        if payload is not None:
            actual = len(payload)
            if actual != declared_length:
                fail(
                    f"version {version}: enclosure is {actual} bytes but the feed declares "
                    f"{declared_length}. A mismatched length is how a truncated or swapped "
                    f"download gets accepted."
                )
            ok(f"version {version}: enclosure length matches ({actual} bytes)")

            # --- 3. Cryptographic verification ---------------------------
            if skip_crypto:
                print(f"  skip  version {version}: signature not checked (--skip-crypto)")
            else:
                public_key = load_public_key(info_plist)
                if verify_signature(public_key, payload, signature_bytes):
                    ok(f"version {version}: signature verifies against the committed public key")
                else:
                    fail(
                        f"version {version}: signature does NOT verify against the key in "
                        f"{info_plist.name}. Do not publish this feed."
                    )
        else:
            print(f"  skip  version {version}: no enclosure bytes available to verify")

    # --- 4. The feed's own signature ----------------------------------------
    # Last, so a feed that is broken in some more basic way is reported for
    # that reason rather than for this one.
    verify_feed_signature(appcast, info_plist)

    print("Appcast is sound.")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("appcast", type=Path, help="path to appcast.xml")
    parser.add_argument(
        "--info-plist", type=Path, default=Path("NepalKit/Info.plist"),
        help="Info.plist carrying SUPublicEDKey (default: NepalKit/Info.plist)",
    )
    parser.add_argument(
        "--enclosure", type=Path, default=None,
        help="local enclosure file to verify; if omitted the URL is fetched",
    )
    parser.add_argument(
        "--skip-crypto", action="store_true",
        help="check structure only, without verifying the signature",
    )
    parser.add_argument(
        "--minimum-system-version", default=None,
        help="the macOS version the app ships as; defaults to DEPLOYMENT_TARGET "
             "in scripts/package-release.sh",
    )
    args = parser.parse_args()

    if not args.appcast.is_file():
        print(f"  FAIL  {args.appcast} does not exist")
        return 1
    if not args.info_plist.is_file():
        print(f"  FAIL  {args.info_plist} does not exist")
        return 1

    try:
        verify(args.appcast, args.info_plist, args.enclosure, args.skip_crypto,
               args.minimum_system_version)
    except SystemExit:
        raise
    except Exception as exc:  # noqa: BLE001
        fail(f"unexpected error: {exc}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
