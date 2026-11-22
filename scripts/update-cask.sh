#!/bin/zsh
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Dibas Sigdel
#
# Usage: scripts/update-cask.sh [version]
#
# With no argument, uses the newest release on GitHub.

set -euo pipefail

ROOT="${0:A:h:h}"
TAP_DIR="${NEPAKIT_TAP_DIR:-$ROOT/../homebrew-tap}"
CASK="$TAP_DIR/Casks/nepalkit.rb"
REPO="dibas-np/NepalKit"
API="https://api.github.com/repos/$REPO"
APP=NepalKit
PBXPROJ="$ROOT/NepalKit.xcodeproj/project.pbxproj"

# shellcheck disable=SC2154
[[ -f "$CASK" ]] || { echo "no cask at $CASK" >&2; exit 1; }

VERSION="${1:-}"
if [[ -z "$VERSION" ]]; then
    VERSION=$(gh api "repos/$REPO/releases/latest" --jq .tag_name)
    echo "using the newest release: $VERSION"
fi
VERSION="${VERSION#v}"
[[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || {
    echo "'$VERSION' is not a three-component version." >&2
    echo "Releases 1.0 to 1.2 shipped two-component versions and are not" >&2
    echo "rewritten; semver starts at 1.3.0." >&2
    exit 1
}

DMG_URL="https://github.com/$REPO/releases/download/v$VERSION/NepalKit.dmg"
echo "==> fetching $DMG_URL"
TMP=$(mktemp -d)
MOUNT_DIR=
cleanup() {
    [[ -n "$MOUNT_DIR" ]] && hdiutil detach "$MOUNT_DIR" >/dev/null 2>&1 || true
    [[ -n "$MOUNT_DIR" ]] && rm -rf "$MOUNT_DIR" >/dev/null 2>&1 || true
    rm -rf "$TMP"
    return 0
}
trap cleanup EXIT
trap 'cleanup; exit 129' HUP
trap 'cleanup; exit 130' INT
trap 'cleanup; exit 143' TERM
curl -fsSL --proto '=https' --tlsv1.2 -o "$TMP/NepalKit.dmg" "$DMG_URL" || {
    echo "could not download the DMG for $VERSION." >&2
    echo "Is the release tagged and does it have NepalKit.dmg attached?" >&2
    exit 1
}

hdiutil verify "$TMP/NepalKit.dmg" >/dev/null 2>&1 || {
    echo "the download is not a valid disk image." >&2
    echo "That usually means the asset name or tag is wrong." >&2
    exit 1
}

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

if ! SPCL_OUT=$(spctl -a -t execute -vv "$DMG_APP" 2>&1); then
    echo "Gatekeeper rejected the app inside the published DMG." >&2
    echo "$SPCL_OUT" >&2
    echo "Refusing to pin a sha256 for it: on the Homebrew path that digest is" >&2
    echo "the only check an install gets." >&2
    exit 1
fi
printf '%s\n' "$SPCL_OUT" | sed 's/^/==> /'

if ! STAPLE_OUT=$(xcrun stapler validate "$DMG_APP" 2>&1); then
    echo "the app inside the published DMG has no stapled notarization ticket." >&2
    echo "$STAPLE_OUT" >&2
    exit 1
fi

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

python3 - "$PBXPROJ" "$DMG_APP/Contents/Info.plist" "$APP" "$VERSION" <<'PYTHON'
import json
import plistlib
import subprocess
import sys

project_path, plist_path, target_name, version = sys.argv[1:]
try:
    project = json.loads(subprocess.check_output(
        ["plutil", "-convert", "json", "-o", "-", project_path]))
    objects = project["objects"]
    targets = [obj for obj in objects.values()
               if obj.get("isa") == "PBXNativeTarget" and obj.get("name") == target_name]
    if len(targets) != 1:
        raise ValueError("cannot identify the macOS app target")
    configs = objects[targets[0]["buildConfigurationList"]]["buildConfigurations"]
    identifiers = {objects[key]["buildSettings"].get("PRODUCT_BUNDLE_IDENTIFIER")
                   for key in configs}
    if len(identifiers) != 1 or not all(isinstance(value, str) and value
                                        for value in identifiers):
        raise ValueError("macOS configurations disagree on the bundle identifier")
    expected_identifier = identifiers.pop()
    with open(plist_path, "rb") as source:
        metadata = plistlib.load(source)
    if not isinstance(metadata, dict):
        raise ValueError("app Info.plist is not a dictionary")
    for field, expected in (("CFBundleIdentifier", expected_identifier),
                            ("CFBundleShortVersionString", version)):
        actual = metadata.get(field)
        if not isinstance(actual, str) or not actual:
            raise ValueError(f"app Info.plist has no valid {field}")
        if actual != expected:
            raise ValueError(f"{field} is {actual}, expected {expected}")
except (OSError, ValueError, KeyError, TypeError, plistlib.InvalidFileException,
        subprocess.CalledProcessError) as error:
    sys.exit(f"Refusing to pin the published DMG: {error}")
print(f"==> app identity and version match {expected_identifier} {version}")
PYTHON

SHA256=$(shasum -a 256 "$TMP/NepalKit.dmg" | awk '{print $1}')
echo "==> sha256 $SHA256"

CURRENT=$(sed -n 's/^  version "\(.*\)"$/\1/p' "$CASK")
echo "==> cask is at $CURRENT, moving it to $VERSION"

grep -q '^  version "' "$CASK" || { echo "no version stanza in $CASK" >&2; exit 1; }
grep -q '^  sha256 "' "$CASK" || { echo "no sha256 stanza in $CASK" >&2; exit 1; }
grep -q '^  url ".*releases/download/' "$CASK" || { echo "no release-download url stanza in $CASK" >&2; exit 1; }

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
