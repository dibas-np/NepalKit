#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Dibas Sigdel
"""Verify a Sparkle appcast before it is published.

Checks, in order: the feed parses, the feed's own EdDSA signature, required
fields, each enclosure's length against its bytes, and each archive's Ed25519
signature against the public key in Info.plist (using openssl, so no private
key is needed and it runs in CI).

Exits non-zero if any item could not be fully verified. `--skip-crypto` checks
structure only; `--allow-partial` reports unverified items but exits 0;
`--embed-notes <dir>` writes release notes into each item's <description> and
exits.
"""

from __future__ import annotations

import argparse
import base64
import re
import sys
import urllib.error
import urllib.request
import xml.etree.ElementTree as ET
from collections.abc import Callable
from html.parser import HTMLParser
from pathlib import Path
from urllib.parse import urlparse

from release_notes import ALLOWED_TAGS as NOTES_TAGS
from sparkle_key import ED25519_SPKI_PREFIX, fail, load_public_key, ok, verify_signature
from xcode_project import macos_floor

SPARKLE_NS = "http://www.andymatuschak.org/xml-namespaces/sparkle"  # NOSONAR
NS = {"sparkle": SPARKLE_NS}

MAX_NOTES_CHARS = 8192

NUMERIC_VERSION = r"[0-9]+\.[0-9]+(?:\.[0-9]+)?"


class _NotesHTMLCheck(HTMLParser):
    def __init__(self) -> None:
        super().__init__(convert_charrefs=True)
        self.offenses: list[str] = []

    def handle_starttag(self, tag, attrs):
        if tag not in NOTES_TAGS:
            self.offenses.append(f"<{tag}>")

    handle_startendtag = handle_starttag

# Sparkle 2 signs a feed by appending a trailing comment block:
#
#     <!-- sparkle-signatures:
#     edSignature: <base64 Ed25519 signature>
#     length: <byte count of the signed content>
#     -->
#
# The signature covers every byte before the block (SPUExtractSignedFeed.m).
FEED_SIGNING_PREFIX = b"<!-- sparkle-signatures:\n"
FEED_SIGNING_SUFFIX = b"-->"


class _HTTPSOnlyRedirects(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        if urlparse(newurl).scheme != "https":
            raise urllib.error.URLError(f"refusing redirect to non-https url {newurl}")
        return super().redirect_request(req, fp, code, msg, headers, newurl)


_OPENER = urllib.request.build_opener(_HTTPSOnlyRedirects)


def fetch(url: str, timeout: int = 60) -> bytes:
    request = urllib.request.Request(url, headers={"User-Agent": "NepalKit-appcast-verify"})
    with _OPENER.open(request, timeout=timeout) as response:
        return response.read()


def extract_feed_signature(raw: bytes) -> tuple[bytes, str | None, int | None]:
    """Split a feed's signing block off, the way Sparkle's client does.

    The search runs backwards, as Sparkle's does.
    """
    start = raw.rfind(FEED_SIGNING_PREFIX)
    if start == -1:
        return raw, None, None
    end = raw.find(FEED_SIGNING_SUFFIX, start + len(FEED_SIGNING_PREFIX))
    if end == -1:
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


def verify_feed_signature(raw: bytes, info_plist: Path) -> None:
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
    if override:
        return override
    return macos_floor()


def replace_items(raw: str, replace: Callable[[str], str]) -> str:
    """Equivalent to `re.sub(r"<item>.*?</item>", ...)` without its quadratic
    rescan from an unclosed <item>.
    """
    parts: list[str] = []
    position = 0
    while (start := raw.find("<item>", position)) != -1:
        end = raw.find("</item>", start)
        if end == -1:
            break
        end += len("</item>")
        parts += [raw[position:start], replace(raw[start:end])]
        position = end
    parts.append(raw[position:])
    return "".join(parts)


def embed_notes(appcast: Path, notes_dir: Path) -> None:
    raw = appcast.read_text(encoding="utf-8")  # NOSONAR

    def describe(block: str) -> str:
        if "<description" in block:
            return block
        found = re.search(r"<sparkle:shortVersionString>([^<]+)</", block)
        version = found.group(1) if found else ""
        if not re.fullmatch(NUMERIC_VERSION, version):
            sys.exit(f"not a numeric release version: {version!r}")
        notes = notes_dir / f"{version}.html"
        if not notes.exists():
            sys.exit(f"no release notes for version {version}: expected {notes}")
        body = notes.read_text(encoding="utf-8").strip()
        if "]]>" in body:
            sys.exit(f"{notes.name}: contains ]]>, which would terminate the CDATA "
                     f"block early and corrupt the feed")
        # Linear find + rstrip rather than a `(\s*)<enclosure` regex, which is
        # quadratic on long whitespace runs. The 12-space indent matches the feed.
        marker = "<enclosure "
        index = block.find(marker)
        if index == -1:
            return block
        prefix = block[:index].rstrip()
        return (f"{prefix}\n            <description><![CDATA[\n{body}\n]]></description>\n"
                f"            {marker}{block[index + len(marker):]}")

    described = replace_items(raw, describe)
    appcast.write_text(described, encoding="utf-8")  # NOSONAR
    ok(f"embedded release notes from {notes_dir}; already-described items left untouched")


def verify(appcast: Path, info_plist: Path, enclosure: Path | None, skip_crypto: bool,
           minimum_system_version: str | None = None, allow_partial: bool = False) -> int:
    print(f"Verifying {appcast}")
    floor = deployment_floor(minimum_system_version)
    if floor:
        print(f"App deployment floor: {floor}")

    feed_bytes = appcast.read_bytes()  # NOSONAR
    signed_content, _, _ = extract_feed_signature(feed_bytes)
    try:
        root = ET.fromstring(signed_content)
    except ET.ParseError as exc:
        fail(f"not well-formed XML: {exc}")
    if not root.tag.endswith("rss"):
        fail(f"root element is <{root.tag}>, expected an RSS document")

    verify_feed_signature(feed_bytes, info_plist)

    items = root.findall("./channel/item")
    if not items:
        fail("feed contains no <item>: an app checking this would see no updates at all")
    ok(f"well-formed, {len(items)} item(s)")

    release_versions = []
    for item in items:
        version = item.findtext("sparkle:shortVersionString", default="", namespaces=NS)
        if not re.fullmatch(NUMERIC_VERSION, version):
            fail(f"invalid release shortVersionString: {version!r}")
        components = tuple(int(part) for part in version.split("."))
        release_versions.append(components + (0,) * (3 - len(components)))
    latest_version = max(release_versions)
    if release_versions.count(latest_version) != 1:
        fail("cannot identify a unique newest release")
    current_item = items[release_versions.index(latest_version)]

    builds = []
    for item in items:
        raw = item.findtext("sparkle:version", default="", namespaces=NS).strip()
        if not re.fullmatch(r"[0-9]+", raw):
            fail(f"item {item.findtext('sparkle:shortVersionString', default='?', namespaces=NS)} "
                 f"has no integer sparkle:version (build number): {raw!r}")
        builds.append(int(raw))
    newest_build = builds[release_versions.index(latest_version)]
    highest_other = max((b for i, b in enumerate(builds) if items[i] is not current_item), default=0)
    if newest_build <= highest_other:
        fail(f"newest release declares build {newest_build}, which is not higher than build "
             f"{highest_other} already offered; Sparkle will offer this update to nobody. "
             f"Bump CURRENT_PROJECT_VERSION.")
    ok(f"newest build {newest_build} is higher than every earlier build")

    if enclosure is not None:
        matches = [item for item in items
                   if item.find("enclosure") is not None
                   and Path(urlparse(item.find("enclosure").get("url", "")).path).name
                   == enclosure.name]
        if len(matches) != 1:
            fail(f"local enclosure {enclosure.name} must match exactly one feed item "
                 f"(found {len(matches)})")

    verified = 0
    skipped: list[str] = []
    fetching = enclosure is None and not skip_crypto

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
            fail(f"version {version}: no <sparkle:minimumSystemVersion>")
        if not re.fullmatch(NUMERIC_VERSION, minimum):
            fail(f"version {version}: malformed minimumSystemVersion {minimum!r}")
        if item is not current_item:
            ok(f"version {version}: historical minimumSystemVersion {minimum}")
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

        payload: bytes | None = None
        if enclosure is not None:
            if Path(parsed.path).name == enclosure.name:
                payload = enclosure.read_bytes()  # NOSONAR
        elif fetching:
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

            if skip_crypto:
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
             "in the Xcode project",
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


if __name__ == "__main__":
    sys.exit(main())
