#!/usr/bin/env python3
"""Regenerate CHANGELOG.md from the per-version release notes.

`scripts/release-notes/<version>.html` is the single source for each
version's notes: verify-appcast.sh injects the fragment into the appcast
item, and this script renders the same fragments as the markdown sections
of CHANGELOG.md. One set of facts, two formats, no third place to drift.

Section headings come from the fragments' `<b>…</b>` blocks, bullets from
`<li>`, and `<p>` paragraphs pass through as text. Version dates come from
the appcast's `pubDate` per item; a version without an appcast item yet is
listed as unreleased.

Usage: update-changelog.py [appcast.xml]

Without an argument the repository's own appcast is read; pass the staged
appcast while packaging a release so the new version picks up its fresh
pubDate. The output is deterministic — running twice changes nothing.
"""

from __future__ import annotations

import re
import sys
from email.utils import parsedate_to_datetime
from html.parser import HTMLParser
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
NOTES_DIR = ROOT / "scripts" / "release-notes"
CHANGELOG = ROOT / "CHANGELOG.md"
DEFAULT_APPCAST = ROOT / "appcast.xml"

HEADER = """\
# Changelog

Notable changes per released version. The same notes, formatted for the
update alert, live at `scripts/release-notes/<version>.html` and ship in
the [appcast](https://dibas-np.github.io/NepalKit/appcast.xml).
"""


class FragmentParser(HTMLParser):
    """Renders one release-notes fragment as markdown blocks.

    The fragments are written by this project to a small contract —
    `<b>Heading:</b>`, `<ul><li>`, and `<p>` — so the parser handles exactly
    those and no more; a foreign tag fails the run rather than being
    silently dropped from the changelog.
    """

    def __init__(self) -> None:
        super().__init__(convert_charrefs=True)
        self.blocks: list[str] = []
        self._buffer: list[str] = []
        self._context: str | None = None

    def handle_starttag(self, tag: str, attrs: list[tuple[str, str | None]]) -> None:
        if tag in ("b", "li", "p") and self._context is None:
            self._context = tag
            self._buffer = []
        elif tag not in ("ul",):
            raise ValueError(f"unsupported tag <{tag}> in release notes")

    def handle_endtag(self, tag: str) -> None:
        text = " ".join("".join(self._buffer).split())
        self._context = None
        self._buffer = []
        if tag == "b":
            self.blocks.append(f"### {text.rstrip(':')}")
        elif tag == "li":
            self.blocks.append(f"- {text}")
        elif tag == "p" and text:
            self.blocks.append(text)

    def handle_data(self, data: str) -> None:
        if self._context is not None:
            self._buffer.append(data)


def render_fragment(path: Path) -> str:
    parser = FragmentParser()
    parser.feed(path.read_text(encoding="utf-8"))
    if parser._context is not None or parser._buffer:  # noqa: SLF001
        raise ValueError(f"{path.name}: ends inside an unfinished <{parser._context}>")
    if not parser.blocks:
        raise ValueError(f"{path.name}: no content")
    lines: list[str] = []
    for block in parser.blocks:
        # Consecutive bullets form one tight markdown list; anything else
        # gets a blank line before it.
        if lines and not (block.startswith("- ") and lines[-1].startswith("- ")):
            lines.append("")
        lines.append(block)
    return "\n".join(lines)


def version_key(stem: str) -> tuple:
    parts = re.findall(r"\d+|\D+", stem)
    return tuple(int(part) if part.isdigit() else part for part in parts)


def release_dates(appcast: Path) -> dict[str, str]:
    """Version → YYYY-MM-DD, from each item's pubDate."""
    raw = appcast.read_text(encoding="utf-8")
    dates: dict[str, str] = {}
    for item in re.findall(r"<item>.*?</item>", raw, flags=re.S):
        version = re.search(r"<sparkle:shortVersionString>([^<]+)</", item)
        pub = re.search(r"<pubDate>([^<]+)</pubDate>", item)
        if version and pub:
            published = parsedate_to_datetime(pub.group(1))
            dates[version.group(1)] = published.date().isoformat()
    return dates


def main() -> int:
    name = Path(sys.argv[0]).name
    if len(sys.argv) > 2:
        print(f"usage: {name} [appcast.xml]", file=sys.stderr)
        return 2

    explicit = len(sys.argv) == 2
    appcast = Path(sys.argv[1]) if explicit else DEFAULT_APPCAST
    if explicit and not appcast.exists():
        # Not the same as a repository that has shipped nothing yet. Both yield
        # no dates, so treating them alike rewrote every released version as
        # "unreleased" and wrote that to CHANGELOG.md with no diagnostic — and
        # the release script commits the changelog it produces. A mistyped or
        # not-yet-staged path has to fail here, where the operator can see it.
        print(f"error: no appcast at {appcast}", file=sys.stderr)
        return 1
    # History comes from the committed feed and only the new release's date from
    # staging. `generate_appcast` prunes a feed to its newest few items, so the
    # staged one legitimately stops carrying older releases — and a release that
    # fell out of the feed must not become "unreleased" in the changelog.
    dates = release_dates(DEFAULT_APPCAST) if DEFAULT_APPCAST.exists() else {}
    if appcast.exists():
        dates.update(release_dates(appcast))

    sections = []
    for path in sorted(NOTES_DIR.glob("*.html"), key=lambda p: version_key(p.stem), reverse=True):
        date = dates.get(path.stem, "unreleased")
        sections.append(f"## {path.stem} — {date}\n\n{render_fragment(path)}")

    CHANGELOG.write_text(HEADER + "\n" + "\n\n".join(sections) + "\n", encoding="utf-8")
    print(f"changelog: {len(sections)} version(s) from {NOTES_DIR.name}/")
    return 0


if __name__ == "__main__":
    sys.exit(main())
