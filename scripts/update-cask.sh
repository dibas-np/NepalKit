#!/bin/zsh
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Dibas Sigdel
#
# Rewrite the Homebrew cask in the tap for a version that is already released.
#
# The cask pins a sha256, and a release's DMG digest is not known until the
# asset is on the release page, so this cannot run as part of packaging. It runs
# after the GitHub release exists, against the published asset - which is also
# the artifact users will verify, rather than a local file that merely looks
# like it.
#
# The cask is rewritten in place rather than templated from a heredoc, because
# the comments in it are load-bearing (they explain why `auto_updates` is set
# and what the zap paths cover) and a generator would have to reproduce them on
# every release for no benefit. Only the two lines that must change are touched.
#
# Usage: scripts/update-cask.sh [version]
#
# With no argument, uses the newest release tag on the remote. The version must
# already be tagged and have its DMG attached, or the checksum below is computed
# over a 404 page and the cask is left pointing at nothing.

set -euo pipefail

ROOT="${0:A:h:h}"
TAP_DIR="${NEPAKIT_TAP_DIR:-$ROOT/../homebrew-tap}"
CASK="$TAP_DIR/Casks/nepalkit.rb"
REPO="dibas-np/NepalKit"
API="https://api.github.com/repos/$REPO"
APP=NepalKit
# Where the signing team is stated. Read rather than hard-coded below, so the
# identity assertion has the same single source of truth the build does.
PBXPROJ="$ROOT/NepalKit.xcodeproj/project.pbxproj"

# shellcheck disable=SC2154
[[ -f "$CASK" ]] || { echo "no cask at $CASK" >&2; exit 1; }

VERSION="${1:-}"
if [[ -z "$VERSION" ]]; then
    VERSION=$(gh api "repos/$REPO/releases/latest" --jq .tag_name)
    echo "using the newest release: $VERSION"
fi
# Tags carry a `v` from v1.3.0 on and the cask records the version without one.
# Stripped here rather than at each use, so an explicit argument accepts the
# spelling a tag actually has instead of failing the check below for having a
# prefix in front of a correct version.
VERSION="${VERSION#v}"
[[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || {
    echo "'$VERSION' is not a three-component version." >&2
    echo "Releases 1.0 to 1.2 shipped two-component versions and are not" >&2
    echo "rewritten; semver starts at 1.3.0 (ADR-0009)." >&2
    exit 1
}

DMG_URL="https://github.com/$REPO/releases/download/v$VERSION/NepalKit.dmg"
echo "==> fetching $DMG_URL"
TMP=$(mktemp -d)
# Empty until the image is attached, so cleanup is a no-op for a download that
# never got as far as mounting. Declared here because the traps read it and
# `set -u` is on.
MOUNT_DIR=
cleanup() {
    [[ -n "$MOUNT_DIR" ]] && hdiutil detach "$MOUNT_DIR" >/dev/null 2>&1 || true
    [[ -n "$MOUNT_DIR" ]] && rm -rf "$MOUNT_DIR" >/dev/null 2>&1 || true
    rm -rf "$TMP"
    return 0
}
trap cleanup EXIT
# EXIT alone is not that guarantee: it does not fire for SIGHUP or SIGTERM, and
# both arrive while the image is attached - a cancelled CI run, or a terminal
# closed mid-download. An image left attached is not merely untidy, it is EBUSY
# for the next run. 128 + signal number, so a signalled run reports why it
# stopped; cleanup runs again on the EXIT those exits trigger, which is
# deliberate rather than guarded against, because every command in it is
# already fault-tolerant and it ends in `return 0`.
trap 'cleanup; exit 129' HUP
trap 'cleanup; exit 130' INT
trap 'cleanup; exit 143' TERM
curl -fsSL -o "$TMP/NepalKit.dmg" "$DMG_URL" || {
    echo "could not download the DMG for $VERSION." >&2
    echo "Is the release tagged and does it have NepalKit.dmg attached?" >&2
    exit 1
}

# A GitHub 404 page is HTML, and its digest is a valid sha256 of exactly the
# wrong bytes - so a bad tag produces a cask that installs something else.
#
# `hdiutil verify` rather than a file-type test: a UDZO disk image reports its
# compression, not its format, so `file` calls a perfectly good DMG
# "application/zlib" and would reject every real release.
hdiutil verify "$TMP/NepalKit.dmg" >/dev/null 2>&1 || {
    echo "the download is not a valid disk image." >&2
    echo "That usually means the asset name or tag is wrong." >&2
    exit 1
}

# Everything from here to the digest is a gate on these bytes, and the digest is
# the trust anchor. Homebrew is the install path that bypasses Sparkle
# (README.md:33-38), so on that path there is no signature check at install
# time: `brew install --cask` verifies the sha256 recorded below and nothing
# else. A release asset replaced by anyone holding release write access but not
# the Developer ID key would therefore be pinned for every Homebrew user, and
# `hdiutil verify` above would pass it, because a substituted file is just as
# well-formed a disk image as the real one.
#
# What follows re-derives, from a fresh network fetch, the assertions
# package-release.sh already made on the machine that produced the asset. Those
# checks are correct and are not what is being changed: this is defence in
# depth, and what it adds is an assertion by the *consumer* about the exact
# bytes it is about to pin. Unexercised so far - the first real run is the next
# tagged release.

# A private mount point, never a fixed /Volumes path. /Volumes is one shared
# namespace, so a predictable name there can already be in use, and mounting
# onto it would attach over - or read from - a volume belonging to something
# else, with nothing in the output to say so. See scripts/package-release.sh:9-14.
MOUNT_DIR=$(mktemp -d "${TMPDIR:-/tmp}/NepalKit-cask-mount.XXXXXXXX")
if ! ATTACH_ERR=$(hdiutil attach -readonly -nobrowse -mountpoint "$MOUNT_DIR" \
        "$TMP/NepalKit.dmg" 2>&1 >/dev/null); then
    echo "could not mount the downloaded image to assess it." >&2
    echo "hdiutil said: $ATTACH_ERR" >&2
    exit 1
fi

DMG_APP="$MOUNT_DIR/$APP.app"
if [[ ! -d "$DMG_APP" ]]; then
    echo "the mounted image has no $APP.app at its root." >&2
    echo "It holds:" >&2
    ls -A "$MOUNT_DIR" >&2
    echo "Pinning a digest for an image that does not contain the app the cask" >&2
    echo "installs would push every Homebrew user at whatever it does hold." >&2
    exit 1
fi

# `spctl -a -t execute` is the assessment the install path ends up making
# anyway; doing it here, before the cask has been rewritten, means a rejection
# is a statement about the asset rather than a cask left half-updated. `-vv`
# because its output names the source - "Notarized Developer ID" against
# "Unnotarized Developer ID" - and that word is the difference between a clean
# build and a signed one nobody ever notarized.
if ! SPCL_OUT=$(spctl -a -t execute -vv "$DMG_APP" 2>&1); then
    echo "Gatekeeper rejected the app inside the published DMG." >&2
    echo "$SPCL_OUT" >&2
    echo "Refusing to pin a sha256 for it: on the Homebrew path that digest is" >&2
    echo "the only check an install gets." >&2
    exit 1
fi
printf '%s\n' "$SPCL_OUT" | sed 's/^/==> /'

# The one assertion the producer's checks cannot make about a re-fetched file.
# package-release.sh staples the .app and separately the .dmg, but that says the
# *file it built* was stapled; a fresh download is a different file that carries
# only whatever ticket it happens to have. Stapled is what makes the install
# work offline - Gatekeeper otherwise has to reach Apple's CDN, which succeeds
# on a good connection and fails on a bad one, and that is how "updates randomly
# fail for some users" starts.
if ! STAPLE_OUT=$(xcrun stapler validate "$DMG_APP" 2>&1); then
    echo "the app inside the published DMG has no stapled notarization ticket." >&2
    echo "$STAPLE_OUT" >&2
    exit 1
fi

# The signing team, read from the project file rather than written here, so
# there is exactly one place it is stated. A literal in this script would be a
# second spelling free to drift, and a check asserting the wrong team fails
# every future release - worse than no check at all.
#
# `sort -u` collapsing to a single line *is* the check that the several build
# configurations agree; six locations spell the team today. More than one
# distinct value means the project file is internally inconsistent, and this
# script does not get to pick a winner.
EXPECTED_TEAM=$(grep -o 'DEVELOPMENT_TEAM = [A-Z0-9]*;' "$PBXPROJ" 2>/dev/null \
    | sed 's/DEVELOPMENT_TEAM = //; s/;//' | sort -u || true)
if [[ -z "$EXPECTED_TEAM" ]]; then
    echo "no DEVELOPMENT_TEAM in $PBXPROJ, so there is no team to assert against." >&2
    echo "Not guessing one. Set it in the project and rerun." >&2
    exit 1
fi
TEAM_COUNT=$(printf '%s\n' "$EXPECTED_TEAM" | wc -l | tr -d ' ')
if [[ "$TEAM_COUNT" -ne 1 ]]; then
    echo "$PBXPROJ states $TEAM_COUNT different DEVELOPMENT_TEAM values:" >&2
    printf '%s\n' "$EXPECTED_TEAM" | sed 's/^/  /' >&2
    echo "Not choosing between them. Resolve the project file, then rerun." >&2
    exit 1
fi

# Distinct from the mismatch below, on purpose. package-release.sh hands
# DEVELOPMENT_TEAM="$TEAM_ID" to the archive step, so the team that actually
# signed a release is whatever the release machine exported - not necessarily
# what the project file carries. When both are present and differ, the cause is
# a stale or wrong export on that machine, and neither value can be asserted
# until they agree; reporting it as a signature mismatch would send whoever
# reads it looking at the DMG instead. In CI this script runs with TEAM_ID
# unset, so the project file is the only source in the path that matters.
if [[ -n "${TEAM_ID:-}" && "$TEAM_ID" != "$EXPECTED_TEAM" ]]; then
    echo "TEAM_ID=$TEAM_ID does not match the project's DEVELOPMENT_TEAM=$EXPECTED_TEAM." >&2
    echo "The release was signed by \$TEAM_ID, so this script cannot say which" >&2
    echo "team those bytes should carry. Unset TEAM_ID, or correct the project" >&2
    echo "file, then rerun." >&2
    exit 1
fi

SIGNED_TEAM=$(codesign -dvv "$DMG_APP" 2>&1 | sed -n 's/^TeamIdentifier=//p' || true)
if [[ -z "$SIGNED_TEAM" ]]; then
    echo "the app inside the published DMG reports no TeamIdentifier." >&2
    codesign -dvv "$DMG_APP" 2>&1 | sed 's/^/  /' >&2
    exit 1
fi
if [[ "$SIGNED_TEAM" != "$EXPECTED_TEAM" ]]; then
    echo "the published DMG is signed by team $SIGNED_TEAM, not $EXPECTED_TEAM." >&2
    echo "Refusing to pin it as this project's cask." >&2
    exit 1
fi
echo "==> signed by team $SIGNED_TEAM, Gatekeeper-clean and stapled"

# The digest goes last, and that ordering is the whole substance of this change.
# Every assertion above is a gate on these bytes; hashing earlier - for a log
# line, or to overlap the download with something else - would compute the
# cask's trust anchor over bytes no check has vouched for, and the failure would
# then surface as an unexplained bad install instead of a rejected release.
# Do not move the shasum above this point.
SHA256=$(shasum -a 256 "$TMP/NepalKit.dmg" | awk '{print $1}')
echo "==> sha256 $SHA256"

CURRENT=$(sed -n 's/^  version "\(.*\)"$/\1/p' "$CASK")
echo "==> cask is at $CURRENT, moving it to $VERSION"

# Fail rather than rewrite when the cask does not already say what this script
# expects to find: an unmatched sed would leave the old version and the old
# digest in place, which reads as a successful bump and installs the old build.
grep -q '^  version "' "$CASK" || { echo "no version stanza in $CASK" >&2; exit 1; }
grep -q '^  sha256 "' "$CASK" || { echo "no sha256 stanza in $CASK" >&2; exit 1; }
grep -q '^  url ".*releases/download/' "$CASK" || { echo "no release-download url stanza in $CASK" >&2; exit 1; }

# The url is rewritten alongside the version, because its tag segment carries the
# `v` and the `#{version}` substitution cannot express that on its own.
perl -pi -e 's/^  version ".*"$/  version "'"$VERSION"'"/' "$CASK"
perl -pi -e 's/^  sha256 ".*"$/  sha256 "'"$SHA256"'"/' "$CASK"
perl -pi -e 's{^(  url ".*)/releases/download/v?[^/]+(/.*)$}{$1/releases/download/v#{version}$2}' "$CASK"

echo "==> verifying the result actually names $VERSION"
grep -q "^  version \"$VERSION\"\$" "$CASK" || { echo "version stanza was not updated" >&2; exit 1; }
grep -q "^  sha256 \"$SHA256\"\$" "$CASK" || { echo "sha256 stanza was not updated" >&2; exit 1; }
grep -Fq "releases/download/v#{version}/" "$CASK" || { echo "url was not updated to the v-prefixed tag" >&2; exit 1; }

if command -v brew >/dev/null; then
    echo "==> brew audit"
    brew audit --cask --tap=dibas-np/tap "$CASK" || {
        echo "audit failed; the cask is modified but not valid." >&2
        exit 1
    }
fi

echo
echo "Updated $CASK to $VERSION. Review and commit it in the tap:"
echo "  git -C $TAP_DIR diff && git -C $TAP_DIR commit -am 'nepalkit $VERSION' && git -C $TAP_DIR push"
