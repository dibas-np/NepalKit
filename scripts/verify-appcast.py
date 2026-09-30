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

Why openssl and not Sparkle's own `sign_update --verify`: verification with
sign_update needs the private key (`--ed-key-file` is rejected for public keys,
and without a key it reads the keychain). That makes it unusable in CI by
design. openssl needs only the public half, which is already committed to the
repository in Info.plist, so the same key that is baked into the shipped app is
the key CI checks against.

An item whose bytes were unavailable is a *counted skipped outcome*, not a
pass: the run says so, names the versions, and exits non-zero. A layer that
did not run is not a layer that passed.

Exit 0 = every item was byte-verified and signature-verified. Non-zero = do
not publish, and do not report the run as a check that happened.

`--skip-crypto` is a "check nothing" flag, not a "skip the hard part" flag: it
suppresses the signature check *and*, through the fetch branch, the byte check
too, so a run using it verifies structure and nothing else. `--allow-partial`
is the release-time escape hatch: it reports unverified items and still exits
0, for the invocation that only has the newly staged archive on disk.
`--embed-notes <dir>` is not a check at all: it rewrites the feed, injecting
release-notes HTML into each item's <description>, and exits. The release
script runs it before its own verification loop.
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


def embed_notes(appcast: Path, notes_dir: Path) -> None:
    """Embed scripts/release-notes/<version>.html into each item's <description>.

    Exactly-once by design: an item that already has a description is left
    untouched, so re-running over a described feed is a no-op. The splice is
    a targeted text substitution rather than an XML reserialisation, so every
    other byte of the file — including anything Sparkle wrote — is untouched.
    """
    raw = appcast.read_text(encoding="utf-8")

    def describe(match: re.Match[str]) -> str:
        block = match.group(0)
        if "<description" in block:
            return block
        version = re.search(r"<sparkle:shortVersionString>([^<]+)</", block).group(1)
        notes = notes_dir / f"{version}.html"
        # sys.exit, not fail(): these two are release-stopping conditions the
        # shell's `set -e` turns into a dead pipeline, and the caller's contract
        # for them is a message on stderr and a non-zero exit. fail() would
        # print to stdout inside a report that otherwise reads as a list of
        # checks, implying a check had run and rejected something.
        if not notes.exists():
            sys.exit(f"no release notes for version {version}: expected {notes}")
        body = notes.read_text(encoding="utf-8").strip()
        if "]]>" in body:
            sys.exit(f"{notes.name}: contains ]]>, which would terminate the CDATA "
                     f"block early and corrupt the feed")
        # The 12-space indent is not cosmetic: the committed feed's formatting
        # depends on it, and an item spliced at a different indent is a feed
        # that reads as hand-edited in the middle of a generated document.
        return re.sub(
            r"(\s*)<enclosure ",
            lambda m: f"\n            <description><![CDATA[\n{body}\n]]></description>\n            <enclosure ",
            block,
            count=1,
        )

    # Nothing is written until the whole pass has succeeded: a half-described
    # feed is a published feed with a silent hole in it, which is strictly worse
    # than a release that stopped.
    described = re.sub(r"<item>.*?</item>", describe, raw, flags=re.S)
    appcast.write_text(described, encoding="utf-8")
    ok(f"embedded release notes from {notes_dir}; already-described items left untouched")


def verify(appcast: Path, info_plist: Path, enclosure: Path | None, skip_crypto: bool,
           minimum_system_version: str | None = None, allow_partial: bool = False) -> int:
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

    # The two outcomes that are neither pass nor fail, counted so the run can
    # report them instead of printing a line and moving on. `verified` counts
    # items that cleared every layer; `skipped` names the ones where a layer
    # could not run, which is what used to be a printed line and a green exit.
    verified = 0
    skipped: list[str] = []

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
                # The bytes were here but the signature was not checked, so
                # this item cleared only one of its two layers. Counted for the
                # same reason the missing-bytes case is.
                skipped.append(version)
                print(f"  skip  version {version}: signature not checked (--skip-crypto)")
            else:
                public_key = load_public_key(info_plist)
                if verify_signature(public_key, payload, signature_bytes):
                    ok(f"version {version}: signature verifies against the committed public key")
                    verified += 1
                else:
                    fail(
                        f"version {version}: signature does NOT verify against the key in "
                        f"{info_plist.name}. Do not publish this feed."
                    )
        else:
            skipped.append(version)
            print(f"  skip  version {version}: no enclosure bytes available to verify")

    if skipped:
        print(
            f"Appcast NOT verified: {verified} of {len(items)} item(s) cleared every "
            f"layer; these did not: {', '.join(skipped)}. A layer that did not run is "
            f"not a pass."
        )
        return 0 if allow_partial else 1
    print("Appcast is sound.")
    return 0


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
        help="check structure only: skips the signature check and the byte check, so "
             "the run verifies nothing and exits non-zero",
    )
    parser.add_argument(
        "--allow-partial", action="store_true",
        help="report items that could not be verified without failing the run. For the "
             "release-time shape, where the feed keeps every release but only the newly "
             "staged archive is on disk. Anything that was checked and found wrong still "
             "fails (default: an unverified item exits non-zero)",
    )
    parser.add_argument(
        "--minimum-system-version", default=None,
        help="the macOS version the app ships as; defaults to DEPLOYMENT_TARGET "
             "in scripts/package-release.sh",
    )
    parser.add_argument(
        "--embed-notes", type=Path, default=None,
        help="embed release-notes HTML from the given directory into each item's "
             "<description>, then exit; mutually exclusive with verifying enclosure bytes",
    )
    args = parser.parse_args()

    if not args.appcast.is_file():
        print(f"  FAIL  {args.appcast} does not exist")
        return 1
    if args.embed_notes is not None:
        # Short-circuited here, in main(), rather than inside verify(): this is a
        # mutation, not a check, and it reads neither the public key nor any
        # enclosure. Putting it after the --info-plist existence test would fail
        # a release over a file the run never opens; putting it inside verify()
        # would leave a mode that can fetch enclosures and sign-check a feed it
        # is in the middle of rewriting, and would leave verify() reporting on
        # bytes it had just changed. The script embeds first and verifies each
        # enclosure in its own loop afterwards, so there is no verdict here to
        # combine with the injection's.
        embed_notes(args.appcast, args.embed_notes)
        return 0
    if not args.info_plist.is_file():
        print(f"  FAIL  {args.info_plist} does not exist")
        return 1

    try:
        return verify(args.appcast, args.info_plist, args.enclosure, args.skip_crypto,
                      args.minimum_system_version, args.allow_partial)
    except SystemExit:
        raise
    except Exception as exc:  # noqa: BLE001
        fail(f"unexpected error: {exc}")
    return 1  # unreachable: fail() exits; here so the return type stays honest


if __name__ == "__main__":
    sys.exit(main())
