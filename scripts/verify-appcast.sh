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
    VERSION="${NEWEST:t:r}"      # NepalKit-1.3.0.zip -> NepalKit-1.3.0
    VERSION="${VERSION#*-}"     # -> 1.3.0
    TAG="v$VERSION"
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
# without this the feed would carry no history at all.
#
# Seeding is necessary but not sufficient: `generate_appcast` then keeps only the
# newest few items and drops the rest on its own — seeding three prior releases
# and adding a fourth yields three, with the oldest removed. That is the tool's
# behaviour rather than a loss this script causes, and it strands nobody, since
# an install on a pruned release is still offered the newest item. What it did
# break was the changelog: `update-changelog.py` read its dates from the feed it
# was handed, so a pruned release became "unreleased". It now takes history from
# the committed feed and only the new date from staging.
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
#
# The splice lives in verify-appcast.py (--embed-notes) rather than in a heredoc
# here, so it is fixture-testable next to the rest of the feed tooling instead
# of being reachable only by running a release. The contract is unchanged, and
# it is deliberately still two steps: embed, then verify each enclosure below.
python3 "$PY" "$APPCAST" --embed-notes "${0:A:h}/release-notes"

# Verify each enclosure locally. Uses only the committed public key, so this is
# safe to run anywhere - including CI, where the private key must never exist.
#
# A partial pass is the expected state here, not a failure. The feed keeps one
# item per release ever published while package-release.sh stages exactly one
# archive, so only the item naming that archive has bytes to check - see the
# comment on the fetch branch in verify-appcast.py. --allow-partial keeps that
# documented gap from blocking a release, and the tally below puts the number in
# the log where it can be read. Anything actually checked and found wrong still
# fails, because that is a FAIL line, not a skip.
STATUS=0
VERIFIED_VERSIONS=""
UNVERIFIED_VERSIONS=""
# Occurrences, not lines: `grep -c '<item>'` counts the lines that mention an
# item, which is only the same number while the generator happens to write one
# per line, and a wrong denominator here would report "1 of 1" over a feed with
# three releases in it.
ITEMS=$(grep -o '<item>' "$APPCAST" | wc -l | tr -d ' ' || true)
for archive in ${ARCHIVES_DIR}/*.(zip|dmg)(N); do
    echo
    echo "verifying against $archive:t"
    output=$(python3 "$PY" "$APPCAST" --info-plist "$PLIST" --enclosure "$archive" --allow-partial) || STATUS=1
    printf '%s\n' "$output"
    # Read back out of the verifier's own lines rather than re-derived here, so
    # the tally below cannot disagree with the report printed above it. Matched
    # on the message text, not on the `ok`/`skip` column layout, so reformatting
    # a prefix does not quietly turn this into a count of zero. The versions are
    # collected rather than counted, because the loop can stage more than one
    # archive and every invocation skips the same un-staged items.
    VERIFIED_VERSIONS="$VERIFIED_VERSIONS
$(printf '%s\n' "$output" | sed -n 's/^.*version \([^:]*\): enclosure length matches.*/\1/p')"
    UNVERIFIED_VERSIONS="$UNVERIFIED_VERSIONS
$(printf '%s\n' "$output" | sed -n 's/^.*version \([^:]*\): no enclosure bytes available to verify.*/\1/p')"
done
VERIFIED=$(printf '%s\n' "$VERIFIED_VERSIONS" | sort -u | grep -c . || true)
UNVERIFIED=$(printf '%s\n' "$UNVERIFIED_VERSIONS" | sort -u | grep -c . || true)

echo
if [[ "$VERIFIED" -eq "$ITEMS" ]]; then
    echo "byte-verified all $ITEMS feed item(s)"
else
    echo "byte-verified $VERIFIED of $ITEMS feed item(s); $UNVERIFIED had no archive in $ARCHIVES_DIR to check"
fi

exit $STATUS
