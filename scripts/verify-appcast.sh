#!/bin/zsh
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Dibas Sigdel
#
# Usage: scripts/verify-appcast.sh <archives-dir> [download-url-prefix]
set -euo pipefail

ROOT="${0:A:h:h}"
REPO_URL="$(sed -n 's/.*repositoryURL = URL(string: "\([^"]*\)").*/\1/p' "$ROOT/NepalKit/AppMetadata.swift" | awk 'NR == 1 { print }')"
[[ -n "$REPO_URL" ]] || { echo "could not read repositoryURL from NepalKit/AppMetadata.swift" >&2; exit 1; }
ARCHIVES_DIR="${1:?usage: $0 <archives-dir> [download-url-prefix]}"
URL_PREFIX="${2:-}"

PY="${ROOT}/scripts/verify-appcast.py"
PLIST="${ROOT}/NepalKit/Info.plist"

if [[ ! -d "$ARCHIVES_DIR" ]]; then
    echo "no such archives directory: $ARCHIVES_DIR" >&2
    exit 1
fi

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

python3 "$ROOT/scripts/sparkle_tools.py" "$GENERATE_APPCAST" "${GENERATE_APPCAST:h}/sign_update"
echo "using $GENERATE_APPCAST"

if [[ -z "$URL_PREFIX" ]]; then
    NEWEST=(${ARCHIVES_DIR}/*.zip(Nom[1]))
    [[ -e "$NEWEST" ]] || NEWEST=(${ARCHIVES_DIR}/*.dmg(Nom[1]))
    [[ -e "$NEWEST" ]] || { echo "no archives in $ARCHIVES_DIR" >&2; exit 1; }
    VERSION="${NEWEST:t:r}"
    VERSION="${VERSION#*-}"
    TAG="v$VERSION"
    URL_PREFIX="$REPO_URL/releases/download/$TAG"
    RELEASE_LINK="$REPO_URL/releases/tag/$TAG"
    echo "derived release tag '$TAG' from ${NEWEST:t}"
else
    RELEASE_LINK="$REPO_URL"
fi

# The trailing slash matters: Foundation's `URL(string:relativeTo:)` replaces
# the base's last path component when it has none.
URL_PREFIX="${URL_PREFIX%/}/"

# generate_appcast only keeps history if an appcast is already in the
# directory, so seed it with the committed feed.
if [[ -f "$ROOT/appcast.xml" ]]; then
    # Its items are about to be signed again, so they must carry a valid signature now.
    if ! seed_check=$(python3 "$PY" "$ROOT/appcast.xml" --info-plist "$PLIST" --skip-crypto --allow-partial 2>&1); then
        printf '%s\n' "$seed_check" >&2
        echo "the committed appcast.xml does not verify; refusing to carry it forward" >&2
        exit 1
    fi
    cp "$ROOT/appcast.xml" "$ARCHIVES_DIR/appcast.xml"
    chmod u+w "$ARCHIVES_DIR/appcast.xml"
    echo "carried forward $(grep -c '<item>' "$ROOT/appcast.xml") existing feed item(s)"
else
    echo "no committed appcast.xml; this will be the first release in the feed"
fi

echo "generating appcast in $ARCHIVES_DIR"
echo "release url prefix: $URL_PREFIX"

"$GENERATE_APPCAST" \
    --maximum-versions 5 \
    --download-url-prefix "$URL_PREFIX" \
    --link "$RELEASE_LINK" \
    "$ARCHIVES_DIR"

APPCAST="$ARCHIVES_DIR/appcast.xml"
[[ -f "$APPCAST" ]] || { echo "generate_appcast did not write an appcast" >&2; exit 1; }

# Embed the release notes from scripts/release-notes/<version>.html.
python3 "$PY" "$APPCAST" --embed-notes "${0:A:h}/release-notes"

SIGN_UPDATE="$(dirname "$GENERATE_APPCAST")/sign_update"
[[ -x "$SIGN_UPDATE" ]] || { echo "no sign_update at $SIGN_UPDATE" >&2; exit 1; }
echo "signing the feed: ${SIGN_UPDATE##*/}"
"$SIGN_UPDATE" "$APPCAST" || {
    echo "sign_update failed; refusing to report a publishable release" >&2
    exit 1
}

STATUS=0
VERIFIED_VERSIONS=""
UNVERIFIED_VERSIONS=""
ITEMS=""
ARCHIVES_CHECKED=0
for archive in ${ARCHIVES_DIR}/*.(zip|dmg)(N); do
    echo
    echo "verifying against $archive:t"
    ARCHIVES_CHECKED=$(( ARCHIVES_CHECKED + 1 ))
    output=$(python3 "$PY" "$APPCAST" --info-plist "$PLIST" --enclosure "$archive" --newest --allow-partial) || STATUS=1
    printf '%s\n' "$output"
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
