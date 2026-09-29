#!/bin/zsh
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Dibas Sigdel
#
# Build the Sparkle appcast for a packaged release, then verify it.
#
# The appcast is generated into a staging directory, not into the repository.
# That is deliberate: `generate_appcast` builds enclosure URLs from a prefix and
# the archive filename, so the `1.0/` release-tag segment has to be supplied per
# version. Baking one into a committed file would silently rot at 1.0.1 - the
# feed would keep pointing at the 1.0 release and every future update 404. The
# feed is a per-release artifact, published alongside the release it describes.
#
# Usage: scripts/verify-appcast.sh <archives-dir> [download-url-prefix]
set -euo pipefail

ROOT="${0:A:h:h}"
# The repository URL has one home: AppMetadata.defaultRepositoryURL. Deriving
# it here keeps the generated feed's enclosure URLs and link from outliving a
# repository move that updated the app and the README but not this script.
REPO_URL="$(sed -n 's/.*defaultRepositoryURL = URL(string: "\([^"]*\)").*/\1/p' "$ROOT/NepalKit/AppMetadata.swift" | head -1)"
[[ -n "$REPO_URL" ]] || { echo "could not read defaultRepositoryURL from NepalKit/AppMetadata.swift" >&2; exit 1; }
ARCHIVES_DIR="${1:?usage: $0 <archives-dir> [download-url-prefix]}"
# Default assumes a GitHub release tag matching the marketing version. Override
# for any other layout, e.g. a flat asset path.
URL_PREFIX="${2:-}"

PY="${ROOT}/scripts/verify-appcast.py"
PLIST="${ROOT}/NepalKit/Info.plist"

if [[ ! -d "$ARCHIVES_DIR" ]]; then
    echo "no such archives directory: $ARCHIVES_DIR" >&2
    exit 1
fi

# Sparkle's tooling is not vendored, and its path contains a DerivedData hash
# that changes per machine. Search for it rather than hardcoding. SPARKLE_BIN
# overrides, which is what CI and a clean checkout use.
if [[ -n "${SPARKLE_BIN:-}" ]]; then
    GENERATE_APPCAST="$SPARKLE_BIN/generate_appcast"
else
    GENERATE_APPCAST=""
    for candidate in ${HOME}/Library/Developer/Xcode/DerivedData/*/SourcePackages/artifacts/sparkle/Sparkle/bin/generate_appcast(N); do
        GENERATE_APPCAST="$candidate"
    done
fi
if [[ -z "$GENERATE_APPCAST" || ! -x "$GENERATE_APPCAST" ]]; then
    echo "generate_appcast not found." >&2
    echo "Set SPARKLE_BIN to the Sparkle bin directory, e.g." >&2
    echo "  SPARKLE_BIN=\$(dirname \$(which generate_appcast)) scripts/verify-appcast.sh <dir>" >&2
    exit 1
fi
echo "using $GENERATE_APPCAST"

if [[ -z "$URL_PREFIX" ]]; then
    # Derive the newest archive's version and use it as the release tag.
    NEWEST=(${ARCHIVES_DIR}/*.zip(Nom[1]))
    [[ -e "$NEWEST" ]] || NEWEST=(${ARCHIVES_DIR}/*.dmg(Nom[1]))
    [[ -e "$NEWEST" ]] || { echo "no archives in $ARCHIVES_DIR" >&2; exit 1; }
    TAG="${NEWEST:t:r}"          # NepalKit-1.0.zip -> NepalKit-1.0
    TAG="${TAG#*-}"             # -> 1.0
    URL_PREFIX="$REPO_URL/releases/download/$TAG"
    RELEASE_LINK="$REPO_URL/releases/tag/$TAG"
    echo "derived release tag '$TAG' from ${NEWEST:t}"
else
    # A caller-supplied prefix is for layouts with no release pages (a flat
    # asset path, say), where a `/releases/tag/...` link would 404. Sparkle
    # shows this as the update's "Learn More" destination, so the repository is
    # the honest fallback rather than a link to nowhere.
    RELEASE_LINK="$REPO_URL"
fi

# The trailing slash is load-bearing, not cosmetic. generate_appcast joins the
# archive name onto this prefix with `URL(string:relativeTo:)`, and Foundation
# resolves a base with no trailing slash by REPLACING its last path component:
# `.../releases/download/1.2` + `NepalKit-1.2.zip` yields
# `.../releases/download/NepalKit-1.2.zip`, which 404s. With the slash it
# appends, and the url is right.
#
# This used to be worked around by generating against a placeholder prefix and
# rewriting every enclosure afterwards, which put this script one post-hoc
# substitution away from repointing the earlier releases into the new release's
# directory - where they 404 too. That is not a hypothetical: it happened, and
# it survived every existing check, because a feed that looks complete and
# serves nothing is still a well-formed feed. Normalising the prefix removes
# the step rather than guarding it.
URL_PREFIX="${URL_PREFIX%/}/"

# Seed the staging directory with the feed this release supersedes.
#
# `generate_appcast` merges into an existing appcast only when one is reachable
# in the archives directory it was pointed at; with none there it starts from
# empty and writes a feed containing this release alone. The staging directory
# is deliberately fresh (it is per-run and private, see package-release.sh), so
# without this the published feed loses 1.0 and 1.1 and every install that
# resolved an update through them loses its path back.
#
# Read from the repository rather than from a copy: the committed appcast is
# what the previous release published, so it is the one that must be carried
# forward. A missing file is not an error - the very first release has no
# predecessor - but it is worth saying out loud, because a feed that has lost
# its history otherwise looks exactly like a successful run.
if [[ -f "$ROOT/appcast.xml" ]]; then
    cp "$ROOT/appcast.xml" "$ARCHIVES_DIR/appcast.xml"
    echo "carried forward $(grep -c '<item>' "$ROOT/appcast.xml") existing feed item(s)"
else
    echo "no committed appcast.xml; this will be the first release in the feed"
fi

echo "generating appcast in $ARCHIVES_DIR"
echo "release url prefix: $URL_PREFIX"

# `--download-url-prefix` carries the version directory itself, so the url
# generate_appcast writes is already the published one and there is nothing to
# correct afterwards. Prior items are read back from the seeded feed and keep
# the urls they were published under. Signing happens here, from the keychain,
# where a human can approve the prompt.
# The link is the release page, not the repository: Sparkle shows it as the
# update's "Learn More" destination, so the bare repo URL drops the release
# notes a user is being offered.
"$GENERATE_APPCAST" \
    --download-url-prefix "$URL_PREFIX" \
    --link "$RELEASE_LINK" \
    "$ARCHIVES_DIR"

APPCAST="$ARCHIVES_DIR/appcast.xml"
[[ -f "$APPCAST" ]] || { echo "generate_appcast did not write an appcast" >&2; exit 1; }

# Embed the release notes. generate_appcast never writes descriptions, so
# without this step every release would depend on remembering a hand edit
# after generation. Notes live in scripts/release-notes/<version>.html as HTML
# fragments, which Sparkle's alert renders, and are matched to items by
# sparkle:shortVersionString. An item whose version has no notes file fails
# the release: an unnoted update alert is the drift this step exists to
# prevent. Re-running over an already-described item is a no-op.
python3 - "$APPCAST" "${0:A:h}/release-notes" <<'PYEOF'
import re
import sys
from pathlib import Path

appcast, notes_dir = Path(sys.argv[1]), Path(sys.argv[2])
raw = appcast.read_text(encoding="utf-8")

def describe(match: "re.Match[str]") -> str:
    block = match.group(0)
    if "<description" in block:
        return block
    version = re.search(r"<sparkle:shortVersionString>([^<]+)</", block).group(1)
    notes = notes_dir / f"{version}.html"
    if not notes.exists():
        sys.exit(f"no release notes for version {version}: expected {notes}")
    body = notes.read_text(encoding="utf-8").strip()
    if "]]>" in body:
        sys.exit(f"{notes.name}: contains ]]>, which would terminate the CDATA "
                 f"block early and corrupt the feed")
    return re.sub(
        r"(\s*)<enclosure ",
        lambda m: f"\n            <description><![CDATA[\n{body}\n]]></description>\n            <enclosure ",
        block,
        count=1,
    )

described = re.sub(r"<item>.*?</item>", describe, raw, flags=re.S)
appcast.write_text(described, encoding="utf-8")
PYEOF

# Verify each enclosure locally. Uses only the committed public key, so this is
# safe to run anywhere - including CI, where the private key must never exist.
STATUS=0
for archive in ${ARCHIVES_DIR}/*.(zip|dmg)(N); do
    echo
    echo "verifying against $archive:t"
    python3 "$PY" "$APPCAST" --info-plist "$PLIST" --enclosure "$archive" || STATUS=1
done

exit $STATUS
