#!/bin/zsh
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Dibas Sigdel
#
# Build the Sparkle appcast for a packaged release in a staging directory,
# sign it, and verify it.
#
# Usage: scripts/verify-appcast.sh <archives-dir> [download-url-prefix]
set -euo pipefail

ROOT="${0:A:h:h}"
# The repository URL is read from AppMetadata.defaultRepositoryURL.
REPO_URL="$(sed -n 's/.*defaultRepositoryURL = URL(string: "\([^"]*\)").*/\1/p' "$ROOT/NepalKit/AppMetadata.swift" | awk 'NR == 1 { print }')"
[[ -n "$REPO_URL" ]] || { echo "could not read defaultRepositoryURL from NepalKit/AppMetadata.swift" >&2; exit 1; }
ARCHIVES_DIR="${1:?usage: $0 <archives-dir> [download-url-prefix]}"
# Defaults to the GitHub release download path for the newest archive's version.
URL_PREFIX="${2:-}"

PY="${ROOT}/scripts/verify-appcast.py"
PLIST="${ROOT}/NepalKit/Info.plist"

if [[ ! -d "$ARCHIVES_DIR" ]]; then
    echo "no such archives directory: $ARCHIVES_DIR" >&2
    exit 1
fi

# SPARKLE_BIN overrides; otherwise only this checkout's own build is used,
# since sign_update reaches the private key.
if [[ -n "${SPARKLE_BIN:-}" ]]; then
    GENERATE_APPCAST="$SPARKLE_BIN/generate_appcast"
else
    GENERATE_APPCAST="$ROOT/DerivedData/SourcePackages/artifacts/sparkle/Sparkle/bin/generate_appcast"
fi
if [[ ! -x "$GENERATE_APPCAST" ]]; then
    echo "generate_appcast not found at $GENERATE_APPCAST." >&2
    echo "Run scripts/check-all.sh (gate 1 builds Sparkle into DerivedData/) or set SPARKLE_BIN" >&2
    echo "to the Sparkle bin directory." >&2
    exit 1
fi

# The binaries have no version flag, so check the tag of the source checkout
# beside them against the pinned version.
if [[ "${SPARKLE_BIN_UNPINNED:-}" != "1" ]]; then
    PINNED_SPARKLE="$(python3 - "$ROOT/NepalKit.xcodeproj/project.pbxproj" <<'PY'
import pathlib, re, sys
text = pathlib.Path(sys.argv[1]).read_text()
# Only Sparkle's own block, so a later package's requirement is never read as it.
block = re.search(
    r'/\* XCRemoteSwiftPackageReference "Sparkle" \*/ = \{'
    r'((?:(?!/\* (?:XCRemoteSwiftPackageReference|End )).)*)',
    text, re.S)
kind = block and re.search(r'kind = (\w+);', block.group(1))
if not kind:
    raise SystemExit("no Sparkle package requirement found in project.pbxproj")
version = re.search(r'version = ([\d.]+);', block.group(1))
if kind.group(1) != "exactVersion" or not version:
    raise SystemExit("Sparkle is pinned as %s, not exactVersion" % kind.group(1))
print(version.group(1))
PY
)"
    SPARKLE_CHECKOUT="$(dirname "$GENERATE_APPCAST")/../../../../checkouts/Sparkle"
    if [[ ! -d "$SPARKLE_CHECKOUT" ]]; then
        echo "no Sparkle source checkout at $SPARKLE_CHECKOUT; cannot confirm the tools match the $PINNED_SPARKLE pin." >&2
        echo "Set SPARKLE_BIN_UNPINNED=1 only for a CI image whose tools live elsewhere, never on the release machine." >&2
        exit 1
    fi
    FOUND_SPARKLE="$(git -C "$SPARKLE_CHECKOUT" describe --tags --exact-match 2>/dev/null || true)"
    if [[ "$FOUND_SPARKLE" != "$PINNED_SPARKLE" ]]; then
        echo "Sparkle tools belong to '${FOUND_SPARKLE:-unknown}', but the pin is $PINNED_SPARKLE; refusing to use them." >&2
        exit 1
    fi
fi
# Both tools must resolve inside the directory the pin check vouched for.
TOOL_DIR="${GENERATE_APPCAST:h:A}"
for tool in "$GENERATE_APPCAST" "${GENERATE_APPCAST:h}/sign_update"; do
    if [[ -e "$tool" && "${tool:A:h}" != "$TOOL_DIR" ]]; then
        echo "$tool resolves outside $TOOL_DIR; refusing to run a Sparkle tool the pin check did not cover." >&2
        exit 1
    fi
done
echo "using $GENERATE_APPCAST"

if [[ -z "$URL_PREFIX" ]]; then
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
    # No release pages for a custom prefix, so link to the repository.
    RELEASE_LINK="$REPO_URL"
fi

# The trailing slash matters: Foundation's `URL(string:relativeTo:)` replaces
# the base's last path component when it has none.
URL_PREFIX="${URL_PREFIX%/}/"

# generate_appcast only keeps history if an appcast is already in the
# directory, so seed it with the committed feed. It keeps the newest five
# versions per compatibility branch.
if [[ -f "$ROOT/appcast.xml" ]]; then
    cp "$ROOT/appcast.xml" "$ARCHIVES_DIR/appcast.xml"
    # The released feed is read-only; generate_appcast rewrites this copy in place.
    chmod u+w "$ARCHIVES_DIR/appcast.xml"
    echo "carried forward $(grep -c '<item>' "$ROOT/appcast.xml") existing feed item(s)"
else
    echo "no committed appcast.xml; this will be the first release in the feed"
fi

echo "generating appcast in $ARCHIVES_DIR"
echo "release url prefix: $URL_PREFIX"

# Each item links to its release page, Sparkle's "Learn More" destination.
"$GENERATE_APPCAST" \
    --maximum-versions 5 \
    --download-url-prefix "$URL_PREFIX" \
    --link "$RELEASE_LINK" \
    "$ARCHIVES_DIR"

APPCAST="$ARCHIVES_DIR/appcast.xml"
[[ -f "$APPCAST" ]] || { echo "generate_appcast did not write an appcast" >&2; exit 1; }

# Embed the release notes from scripts/release-notes/<version>.html. A
# version without a notes file fails the release.
python3 "$PY" "$APPCAST" --embed-notes "${0:A:h}/release-notes"

# Sign the feed last: generate_appcast and --embed-notes both change signed
# bytes. Skipped when sign_update is absent (CI), where the verification
# below still catches a stale signature.
SIGN_UPDATE="$(dirname "$GENERATE_APPCAST")/sign_update"
if [[ -x "$SIGN_UPDATE" ]]; then
  echo "signing the feed: ${SIGN_UPDATE##*/}"
  "$SIGN_UPDATE" "$APPCAST" || {
      echo "sign_update failed; refusing to report a publishable release" >&2
      exit 1
  }
else
  echo "no sign_update at $SIGN_UPDATE; verifying the feed as committed (CI path)"
fi

# Verify each enclosure against the committed public key. The feed has every
# release but only the new archive is staged, so --allow-partial is expected.
STATUS=0
VERIFIED_VERSIONS=""
UNVERIFIED_VERSIONS=""
# The item count comes from the verifier's "well-formed, N item(s)" line.
ITEMS=""
ARCHIVES_CHECKED=0
for archive in ${ARCHIVES_DIR}/*.(zip|dmg)(N); do
    echo
    echo "verifying against $archive:t"
    ARCHIVES_CHECKED=$(( ARCHIVES_CHECKED + 1 ))
    output=$(python3 "$PY" "$APPCAST" --info-plist "$PLIST" --enclosure "$archive" --allow-partial) || STATUS=1
    printf '%s\n' "$output"
    # Tally from the verifier's own messages so the summary matches its report.
    VERIFIED_VERSIONS="$VERIFIED_VERSIONS
$(printf '%s\n' "$output" | sed -n 's/^.*version \([^:]*\): enclosure length matches.*/\1/p')"
    UNVERIFIED_VERSIONS="$UNVERIFIED_VERSIONS
$(printf '%s\n' "$output" | sed -n 's/^.*version \([^:]*\): no enclosure bytes available to verify.*/\1/p')"
    count=$(printf '%s\n' "$output" | sed -n 's/^.*well-formed, \([0-9][0-9]*\) item(s).*/\1/p' | awk 'NR == 1 { print }')
    ITEMS=${count:-$ITEMS}
done
VERIFIED=$(printf '%s\n' "$VERIFIED_VERSIONS" | sort -u | grep -c . || true)
UNVERIFIED=$(printf '%s\n' "$UNVERIFIED_VERSIONS" | sort -u | grep -c . || true)

echo
if (( ARCHIVES_CHECKED == 0 )); then
    echo "no .zip or .dmg in $ARCHIVES_DIR, so nothing was verified against an archive" >&2
    STATUS=1
elif [[ -z "$ITEMS" ]]; then
    echo "the verifier stopped before counting the feed's items; its FAIL line above says why" >&2
    STATUS=1
elif [[ "$VERIFIED" -eq "$ITEMS" ]]; then
    echo "byte-verified all $ITEMS feed item(s)"
else
    echo "byte-verified $VERIFIED of $ITEMS feed item(s); $UNVERIFIED had no archive in $ARCHIVES_DIR to check"
fi

exit $STATUS
