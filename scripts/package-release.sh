#!/bin/zsh

# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Dibas Sigdel
set -euo pipefail

ROOT="${0:A:h:h}"
APP=NepalKit
# Every intermediate artifact lives in a per-run private directory, not in
# fixed /tmp/<name> paths: /tmp is world-writable and sticky, so a predictable
# path there can be pre-planted with a symlink by any local account, and two
# concurrent releases would collide. mktemp -d creates a 0700 directory whose
# name cannot be guessed.
WORK="$(mktemp -d "${TMPDIR:-/tmp}/NepalKit-release.XXXXXXXX")"
DEPLOYMENT_TARGET=26.0
ARCHIVE="$WORK/$APP.xcarchive"
EXPORT_DIR="$WORK/${APP}-export"
APP_PATH="$EXPORT_DIR/$APP.app"
DMG="$WORK/$APP.dmg"
# Submitted to Apple. Rebuilt later as $DIST_ZIP, after the staple lands.
NOTARY_ZIP="$WORK/${APP}-for-notary.zip"

# The drag-install DMG and the writable image its window is laid out on. See
# the DMG section below for why there are two images and why hdiutil is
# involved; the paths live here because the cleanup trap needs them.
BACKGROUND=dmg-background@2x.png
DMG_LAYOUT="$WORK/${APP}-layout.dmg"
# Unique on purpose. The volume's own name has to be $APP — the background's
# alias is recorded against it — but Finder identifies a mounted disk by the
# last component of wherever it is mounted, so a name already in use on this
# Mac would silently script the wrong volume. That failure is invisible: the
# layout is written to a volume nobody ships, and the DMG comes out default.
DMG_LAYOUT_MOUNT=/Volumes/${APP}-layout
# Big enough for the stapled app and the artwork with room to spare. The
# compressed image that comes out is a fraction of this.
DMG_LAYOUT_SIZE=300m
DMG_LAYOUT_DEVICE=
MNT=/Volumes/${APP}-release-check

# Computed at use, not here: the export has not run yet at this point in the
# script, so reading its Info.plist now would silently yield "0" in the name.
DIST_ZIP=

# Everything this script mounts is unmounted on the way out, including when it
# fails partway. A read-write image left attached is not merely untidy: it is
# EBUSY, and the next run's conversion then fails with a message that never
# mentions attachments.
cleanup() {
    diskutil unmount "$MNT" >/dev/null 2>&1 || true
    diskutil unmount "$DMG_LAYOUT_MOUNT" >/dev/null 2>&1 || true
    [[ -n "$DMG_LAYOUT_DEVICE" ]] && diskutil eject "$DMG_LAYOUT_DEVICE" >/dev/null 2>&1
    rm -rf "$WORK"
    return 0
}
trap cleanup EXIT

# Resolve how to authenticate to the notary service.
#
# A keychain profile is the only supported path, and the only one that puts
# nothing secret in argv. notarytool's env-var form (APPLE_ID /
# APP_SPECIFIC_PASSWORD) is deliberately not implemented here: it would put
# the app-specific password in the process table for the length of each
# submission, and there is no CI release path that needs it.
#
# The profile's contents are NOT parsed here. notarytool stores a JSON blob under
# service "appSpecificPassword" with account
# "com.apple.gke.notary.tool.saved-creds.<profile>", and only notarytool knows how
# to read it. Existence is therefore detected by asking whether the item is
# there, and the profile is then passed through untouched.
NOTARY_PROFILE="${NOTARY_PROFILE:-NepalKit-notary}"

if [[ -z "${TEAM_ID:-}" ]]; then
    echo "TEAM_ID is required for Developer ID signing/export."
    exit 2
fi

NOTARY_ARGS=(--keychain-profile "$NOTARY_PROFILE")

echo "notary credentials: keychain profile '$NOTARY_PROFILE'"


# Explicitly require a Developer ID Application certificate for this team —
# a generic codesigning identity is not enough for distribution.
# (The `|| true` keeps `set -euo pipefail` from firing on no match so the
# friendly error below runs instead.)
IDENTITY="$(security find-identity -v -p codesigning \
    | grep -o "Developer ID Application: .* ($TEAM_ID)" | head -1 || true)"
[[ -n "$IDENTITY" ]] || {
    echo "no Developer ID Application certificate for team $TEAM_ID in this keychain"
    exit 2
}
echo "signing as: $IDENTITY"

cat > "$WORK/${APP}-ExportOptions.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key><string>developer-id</string>
    <key>teamID</key><string>$TEAM_ID</string>
    <key>signingStyle</key><string>automatic</string>
    <key>hardenedRuntime</key><true/>
</dict>
</plist>
EOF

# Explicit deployment target: the release artifact must never silently
# inherit a different floor from Xcode project state.
#
# generic/platform=macOS, not platform=macOS: the latter matches both arm64 and
# x86_64 on a machine that has both, and Xcode warns that it is picking the
# first arbitrarily. generic/ is the universal build and matches exactly one.
#
# The comment sits above the command rather than inside it: a `#` comment
# between the parts of a backslash-continued command is spliced into the
# command line, and the rest of it then runs as a command of its own.
MACOSX_DEPLOYMENT_TARGET=$DEPLOYMENT_TARGET xcodebuild -project "$ROOT/$APP.xcodeproj" -scheme "$APP" \
    -destination 'generic/platform=macOS' -configuration Release \
    CODE_SIGN_STYLE=Manual CODE_SIGN_IDENTITY="$IDENTITY" DEVELOPMENT_TEAM="$TEAM_ID" \
    -archivePath "$ARCHIVE" archive
xcodebuild -exportArchive -archivePath "$ARCHIVE" \
    -exportPath "$EXPORT_DIR" -exportOptionsPlist "$WORK/${APP}-ExportOptions.plist"

# Verify the exported app before it goes anywhere near a DMG.
codesign --verify --deep --strict --verbose=2 "$APP_PATH"
codesign -dv --verbose=4 "$APP_PATH" 2>&1 | tee "$WORK/${APP}-codesign.txt"
grep -q "flags=.*runtime" "$WORK/${APP}-codesign.txt" || {
    echo "hardened runtime flag missing from signature"
    exit 1
}

# Notarize the APP, not only the DMG.
#
# Sparkle never hands a user the DMG. It extracts the enclosure and copies the
# .app over the installed one, so a ticket stapled to the DMG is thrown away on
# every single update and Gatekeeper is left fetching a fresh one from Apple's
# CDN at update time. That succeeds on a good connection and fails on a poor
# one, which is exactly how "updates randomly fail for some users" begins.
#
# Apple issues a ticket per submitted item, so the .app has to be submitted in
# its own right: stapling it beforehand fails with "Error 73" because there is
# no ticket for it to staple. notarytool takes a zip rather than a bare bundle.
# The staple then lands on the .app in the export directory, and the DMG below
# is assembled *from that stapled app*, so both paths stay clean.
ditto -c -k --sequesterRsrc --keepParent "$APP_PATH" "$NOTARY_ZIP"
xcrun notarytool submit "$NOTARY_ZIP" "${NOTARY_ARGS[@]}" --wait
xcrun stapler staple "$APP_PATH"
xcrun stapler validate "$APP_PATH"
# The check that would have caught this. A stapled DMG passed here for months
# while the app inside it had no ticket at all, so the DMG was the wrong thing
# to be validating. This is the assertion that matters for Sparkle.
spctl -a -t execute -vv "$APP_PATH"
echo "app notarized and stapled: $APP_PATH"

# DMG with an Applications shortcut for drag-install, in a window laid out to
# match the artwork the user is met with when they open it.
#
# The window cannot be built by copying files into a folder and asking
# `diskutil image create from` for a DMG. That deliberately drops `.DS_Store`,
# which is where Finder keeps window geometry and the background picture, so an
# image built that way is a default Finder window no matter what the staging
# directory contains. The layout has to be written by Finder onto a mounted,
# writable volume, and the shipped image has to be made from that volume
# afterwards.
#
# hdiutil, deliberately, twice, and both calls warn. `diskutil image create
# blank` is the supported way to make a read-write image, but every filesystem
# it offers either cannot hold the Applications symlink (ExFAT, MS-DOS) or is
# wrapped in an APFS container that cannot be converted to a compressed UDZO
# image at all. A single-volume HFS+ image can, and `hdiutil convert` is the
# only thing that performs that conversion: Apple's deprecation notice points
# at `diskutil image create from`, which fails with EBUSY on a disk-image
# source. The warnings are filtered out below, because a release log that
# always carries a deprecation notice teaches people to stop reading it.
HDIUTIL_LOG="$WORK/${APP}-hdiutil.log"
hdiutil_run() {
    hdiutil "$@" 2>"$HDIUTIL_LOG" || {
        echo "hdiutil $1 failed:" >&2
        cat "$HDIUTIL_LOG" >&2
        exit 1
    }
    grep -v "is deprecated" "$HDIUTIL_LOG" >&2 || true
}

# The window is laid out and read back by scripting Finder, which is a
# permission this machine may not have granted yet: the first osascript that
# tries to control Finder comes back -1743, and that error does not mention
# permissions. Translated here, because a release that stops for want of a
# setting is otherwise a puzzle.
finder_run() {
    osascript "$@" || {
        echo "$1 failed." >&2
        echo "If this is error -1743, this terminal is not allowed to control" >&2
        echo "Finder yet: System Settings > Privacy & Security > Automation." >&2
        exit 1
    }
}

rm -f "$DMG_LAYOUT"
hdiutil_run create -size "$DMG_LAYOUT_SIZE" -fs HFS+ -volname "$APP" "$DMG_LAYOUT"
# The plist is the only non-deprecated way to learn that identifier:
# `diskutil image attach` prints the volume's, and ejecting the volume leaves
# the image attached.
DMG_LAYOUT_DEVICE=$(diskutil image attach "$DMG_LAYOUT" --mountPoint "$DMG_LAYOUT_MOUNT" --plist \
    | plutil -extract system-entities.0.dev-entry raw -o - -)

mkdir -p "$DMG_LAYOUT_MOUNT/.background"
ditto "$APP_PATH" "$DMG_LAYOUT_MOUNT/$APP.app"
ln -s /Applications "$DMG_LAYOUT_MOUNT/Applications"
LAYOUT=$(swift "$ROOT/scripts/make-dmg-artwork.swift" "$DMG_LAYOUT_MOUNT/.background/$BACKGROUND" "$APP")
finder_run "$ROOT/scripts/dmg-layout.applescript" "${APP}-layout" "$APP" \
    "$DMG_LAYOUT_MOUNT/.background/$BACKGROUND" "$LAYOUT"

# Finder's change log is written while the volume is mounted and has no business
# in a shipped image.
rm -rf "$DMG_LAYOUT_MOUNT/.fseventsd"
# Unmount, then eject. Ejecting is what actually releases the image: an image
# that is still attached is EBUSY, and the conversion below fails with a
# message that does not mention attachments at all.
diskutil unmount "$DMG_LAYOUT_MOUNT"
diskutil eject "$DMG_LAYOUT_DEVICE"

rm -f "$DMG"
hdiutil_run convert "$DMG_LAYOUT" -format UDZO -o "$DMG"

xcrun notarytool submit "$DMG" "${NOTARY_ARGS[@]}" --wait
xcrun stapler staple "$DMG"

# "Gatekeeper-clean" is earned only here. Note the assessment order, each a
# hard gate: the ticket on the DMG first, then the app users actually launch.
# (A DMG carries no code signature by design, so `spctl` on the .dmg file
# itself always reports "no usable signature" — the meaningful checks are
# the stapled ticket plus the mounted app.)
xcrun stapler validate "$DMG"

# No `--mountOptions nobrowse` here, unlike every other mount in this script:
# the window check below asks Finder what the window looks like, and Finder
# cannot answer for a volume it has been told not to show. The window that opens
# on screen during a release is the price of checking it.
diskutil image attach "$DMG" --mountPoint "$MNT" >/dev/null

# The window, read back off the finished image.
#
# This is a hard gate because every other gate in this script passes just as
# happily on a DMG whose window is Finder's default: the image is signed,
# notarized, stapled and Gatekeeper-clean either way, and the layout lives in
# an undocumented file that Apple is free to stop reading. A release that ships
# a default window should fail here, loudly, rather than in a bug report.
finder_run "$ROOT/scripts/verify-dmg-layout.applescript" "${APP}-release-check" "$APP" "$LAYOUT"

# The background picture is the one part of the layout AppleScript cannot read
# back: `background picture` is declared as a `file` and every way of asking
# for it fails with -10000 whether or not one is set. So it is checked in the
# place it is actually stored — the icon view options inside `.DS_Store`, which
# name the artwork they point at.
strings -a "$MNT/.DS_Store" | grep -q "$BACKGROUND" || {
    echo "the DMG window has no background picture: .DS_Store never names $BACKGROUND"
    exit 1
}
[[ -f "$MNT/.background/$BACKGROUND" ]] || {
    echo "the DMG window's background picture is not in the image"
    exit 1
}

spctl -a -t execute "$MNT/$APP.app"

# Launch smoke: the notarized app must start from the mounted DMG.
open "$MNT/$APP.app"
launched=0
for _ in {1..15}; do
    if pgrep -f "$MNT/$APP.app/Contents/MacOS/$APP" >/dev/null; then launched=1; break; fi
    sleep 1
done
[[ $launched == 1 ]] || { echo "app did not launch from mounted DMG"; exit 1; }
pkill -f "$MNT/$APP.app/Contents/MacOS/$APP" || true

# The Sparkle enclosure: the stapled app, zipped *after* stapling so the ticket
# is inside it. Rebuilt rather than reusing $NOTARY_ZIP, which predates the
# staple and would ship without one.
VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" \
    "$APP_PATH/Contents/Info.plist")
DIST_ZIP="$WORK/${APP}-${VERSION}.zip"
rm -f "$DIST_ZIP"
ditto -c -k --sequesterRsrc --keepParent "$APP_PATH" "$DIST_ZIP"
# Same signature check as the DMG: Sparkle verifies this exact file, so it is
# the artifact that actually has to be Gatekeeper-accepting.
unzip -qo "$DIST_ZIP" -d "$WORK/${APP}-dist-verify"
spctl -a -t execute -vv "$WORK/${APP}-dist-verify/$APP.app"
rm -rf "$WORK/${APP}-dist-verify"

# Build and verify the appcast for this version. Signing needs the keychain, so
# this runs on the release machine, never in CI.
APPCAST_DIR="$WORK/${APP}-appcast-$VERSION"
rm -rf "$APPCAST_DIR"
mkdir -p "$APPCAST_DIR"
cp "$DIST_ZIP" "$APPCAST_DIR/"
"${0:A:h}/verify-appcast.sh" "$APPCAST_DIR" || {
    echo "appcast verification failed; refusing to report a publishable release"
    exit 1
}

# CHANGELOG.md is generated, not hand-edited: the same notes files the
# appcast step just embedded render as its markdown sections, and the new
# version's date comes from the fresh pubDate in the staged appcast. The
# working-tree change is committed with the appcast, never re-typed later.
python3 "$ROOT/scripts/update-changelog.py" "$APPCAST_DIR/appcast.xml"

# The workspace dies with the run, but the release outputs do not: they are
# copied to a directory beside it that the operator keeps.
OUT_DIR="${TMPDIR:-/tmp}/NepalKit-release-output-$$"
mkdir -p "$OUT_DIR"
cp "$DMG" "$DIST_ZIP" "$APPCAST_DIR/appcast.xml" "$OUT_DIR/"

echo "Gatekeeper-clean DMG: $OUT_DIR/$(basename "$DMG")"
echo "Sparkle enclosure (stapled, zipped): $OUT_DIR/$(basename "$DIST_ZIP")"
echo "Signed appcast: $OUT_DIR/appcast.xml"
echo "Changelog updated: $ROOT/CHANGELOG.md"
