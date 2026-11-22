#!/usr/bin/env python3
"""Regenerate CHANGELOG.md from scripts/release-notes/<version>.html.

Dates come from each appcast item's pubDate, but a date already in
CHANGELOG.md is kept. Versions with no date are listed as unreleased.

Usage: update-changelog.py [appcast.xml]

Without an argument the repository's appcast.xml is read; pass the staged
appcast while packaging so the new version gets its pubDate.
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

    Only `<b>Heading:</b>`, `<ul><li>` and `<p>` are allowed; any other tag
    is an error.
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
        if lines and not (block.startswith("- ") and lines[-1].startswith("- ")):
            lines.append("")
        lines.append(block)
    return "\n".join(lines)


def version_key(stem: str) -> tuple:
    parts = re.findall(r"\d+|\D+", stem)
    return tuple(int(part) if part.isdigit() else part for part in parts)


def release_dates(appcast: Path) -> dict[str, str]:
    """Version → YYYY-MM-DD, from each item's pubDate."""
    # NOSONAR, for the reason recorded in scripts/verify-appcast.py: the feed is
    # the argument, the caller is the operator or the release script, and
    # confining the path to a base directory would break the staged-feed run.
    raw = appcast.read_text(encoding="utf-8")  # NOSONAR
    dates: dict[str, str] = {}
    for item in re.findall(r"<item>.*?</item>", raw, flags=re.S):
        version = re.search(r"<sparkle:shortVersionString>([^<]+)</", item)
        pub = re.search(r"<pubDate>([^<]+)</pubDate>", item)
        if version and pub:
            published = parsedate_to_datetime(pub.group(1))
            dates[version.group(1)] = published.date().isoformat()
    return dates


def resolve_dates(committed: Path, staged: Path, changelog: Path) -> dict[str, str]:
    """Version → YYYY-MM-DD. Dates already in the changelog win over both feeds."""
    dates: dict[str, str] = {}
    if committed.exists():
        dates.update(release_dates(committed))
    if staged.exists():
        dates.update(release_dates(staged))

    # Changelog dates are applied last: generate_appcast prunes old items, so the
    # feeds alone would turn old releases back into "unreleased".
    for heading in re.finditer(
        r"^## (\S+) — (\d{4}-\d{2}-\d{2})$",
        changelog.read_text(encoding="utf-8"),
        re.MULTILINE,
    ):
        dates[heading.group(1)] = heading.group(2)
    return dates


def main() -> int:
    name = Path(sys.argv[0]).name
    if len(sys.argv) > 2:
        print(f"usage: {name} [appcast.xml]", file=sys.stderr)
        return 2

    explicit = len(sys.argv) == 2
    appcast = Path(sys.argv[1]) if explicit else DEFAULT_APPCAST
    if explicit and not appcast.exists():
        # Fail rather than rewrite every release as "unreleased".
        print(f"error: no appcast at {appcast}", file=sys.stderr)
        return 1
    dates = resolve_dates(DEFAULT_APPCAST, appcast, CHANGELOG)

    sections = []
    for path in sorted(NOTES_DIR.glob("*.html"), key=lambda p: version_key(p.stem), reverse=True):
        date = dates.get(path.stem, "unreleased")
        sections.append(f"## {path.stem} — {date}\n\n{render_fragment(path)}")

    CHANGELOG.write_text(HEADER + "\n" + "\n\n".join(sections) + "\n", encoding="utf-8")
    print(f"changelog: {len(sections)} version(s) from {NOTES_DIR.name}/")
    return 0


if __name__ == "__main__":
    sys.exit(main())
