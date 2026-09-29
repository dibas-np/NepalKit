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

# shellcheck disable=SC2154
[[ -f "$CASK" ]] || { echo "no cask at $CASK" >&2; exit 1; }

VERSION="${1:-}"
if [[ -z "$VERSION" ]]; then
    VERSION=$(gh api "repos/$REPO/releases/latest" --jq .tag_name)
    echo "using the newest release: $VERSION"
fi
[[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || {
    echo "'$VERSION' is not a three-component version." >&2
    echo "Releases 1.0 to 1.2 shipped two-component versions and are not" >&2
    echo "rewritten; semver starts at 1.3.0 (ADR-0009)." >&2
    exit 1
}

DMG_URL="https://github.com/$REPO/releases/download/$VERSION/NepalKit.dmg"
echo "==> fetching $DMG_URL"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
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

SHA256=$(shasum -a 256 "$TMP/NepalKit.dmg" | awk '{print $1}')
echo "==> sha256 $SHA256"

CURRENT=$(sed -n 's/^  version "\(.*\)"$/\1/p' "$CASK")
echo "==> cask is at $CURRENT, moving it to $VERSION"

# Fail rather than rewrite when the cask does not already say what this script
# expects to find: an unmatched sed would leave the old version and the old
# digest in place, which reads as a successful bump and installs the old build.
grep -q '^  version "' "$CASK" || { echo "no version stanza in $CASK" >&2; exit 1; }
grep -q '^  sha256 "' "$CASK" || { echo "no sha256 stanza in $CASK" >&2; exit 1; }

perl -pi -e 's/^  version ".*"$/  version "'"$VERSION"'"/' "$CASK"
perl -pi -e 's/^  sha256 ".*"$/  sha256 "'"$SHA256"'"/' "$CASK"

echo "==> verifying the result actually names $VERSION"
grep -q "^  version \"$VERSION\"\$" "$CASK" || { echo "version stanza was not updated" >&2; exit 1; }
grep -q "^  sha256 \"$SHA256\"\$" "$CASK" || { echo "sha256 stanza was not updated" >&2; exit 1; }

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
