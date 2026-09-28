#!/bin/zsh

# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Dibas Sigdel
# Release pipeline (ticket 08): archive, Developer ID export, notarize and staple
# the APP, then a DMG for humans and a zip for Sparkle. Both are Gatekeeper-verified.
# The app is notarized separately and first: see the note above, it is load-bearing.
#
# NOT YET PROVEN: needs a paid Apple Developer account. Provide credentials
# via env (APPLE_ID, APP_SPECIFIC_PASSWORD, TEAM_ID); without them the script
# stops after the checks step with instructions. Requires network to Apple.
# No need to wait for the final UI: once the certificate exists, run this
# against the current build and prove Xcode → Archive → Developer ID → DMG →
# Notarize → Staple → Gatekeeper.
#
# Usage (repo root): APPLE_ID=you@example.com APP_SPECIFIC_PASSWORD=xxxx \
#   TEAM_ID=XXXXXXXXXX scripts/package-release.sh
set -euo pipefail

ROOT="${0:A:h:h}"
APP=NepalKit
DEPLOYMENT_TARGET=26.0
ARCHIVE=/tmp/$APP.xcarchive
EXPORT_DIR=/tmp/${APP}-export
APP_PATH="$EXPORT_DIR/$APP.app"
STAGE=/tmp/${APP}-dmg
DMG=/tmp/$APP.dmg
# Submitted to Apple. Rebuilt later as $DIST_ZIP, after the staple lands.
NOTARY_ZIP=/tmp/${APP}-for-notary.zip
# Computed at use, not here: the export has not run yet at this point in the
# script, so reading its Info.plist now would silently yield "0" in the name.
DIST_ZIP=

[[ -n "${APPLE_ID:-}" && -n "${APP_SPECIFIC_PASSWORD:-}" && -n "${TEAM_ID:-}" ]] || {
    echo "missing credentials: set APPLE_ID, APP_SPECIFIC_PASSWORD, TEAM_ID"
    echo "create an app-specific password at https://account.apple.com"
    exit 2
}

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

cat > /tmp/${APP}-ExportOptions.plist <<EOF
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
    -exportPath "$EXPORT_DIR" -exportOptionsPlist /tmp/${APP}-ExportOptions.plist

# Verify the exported app before it goes anywhere near a DMG.
codesign --verify --deep --strict --verbose=2 "$APP_PATH"
codesign -dv --verbose=4 "$APP_PATH" 2>&1 | tee /tmp/${APP}-codesign.txt
grep -q "flags=.*runtime" /tmp/${APP}-codesign.txt || {
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
xcrun notarytool submit "$NOTARY_ZIP" --apple-id "$APPLE_ID" \
    --password "$APP_SPECIFIC_PASSWORD" --team-id "$TEAM_ID" --wait
xcrun stapler staple "$APP_PATH"
xcrun stapler validate "$APP_PATH"
# The check that would have caught this. A stapled DMG passed here for months
# while the app inside it had no ticket at all, so the DMG was the wrong thing
# to be validating. This is the assertion that matters for Sparkle.
spctl -a -t execute -vv "$APP_PATH"
echo "app notarized and stapled: $APP_PATH"

# DMG with an Applications shortcut for drag-install.
rm -rf "$STAGE"
mkdir -p "$STAGE"
cp -R "$APP_PATH" "$STAGE/"
ln -s /Applications "$STAGE/Applications"
rm -f "$DMG"
# diskutil, not hdiutil: `hdiutil create -volname -format` is deprecated and
# says so on every run. Same image, supported spelling.
diskutil image create from "$STAGE" --volumeName "$APP" --format UDZO "$DMG" >/dev/null

xcrun notarytool submit "$DMG" --apple-id "$APPLE_ID" \
    --password "$APP_SPECIFIC_PASSWORD" --team-id "$TEAM_ID" --wait
xcrun stapler staple "$DMG"

# "Gatekeeper-clean" is earned only here. Note the assessment order, each a
# hard gate: the ticket on the DMG first, then the app users actually launch.
# (A DMG carries no code signature by design, so `spctl` on the .dmg file
# itself always reports "no usable signature" — the meaningful checks are
# the stapled ticket plus the mounted app.)
xcrun stapler validate "$DMG"

MNT=/Volumes/${APP}-release-check
cleanup() { diskutil unmount "$MNT" >/dev/null 2>&1 || true; }
trap cleanup EXIT
# diskutil, not hdiutil: `hdiutil attach -nobrowse -mountpoint` is
# deprecated and says so on every run.
diskutil image attach "$DMG" --mountOptions nobrowse --mountPoint "$MNT" >/dev/null
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
DIST_ZIP=/tmp/${APP}-${VERSION}.zip
rm -f "$DIST_ZIP"
ditto -c -k --sequesterRsrc --keepParent "$APP_PATH" "$DIST_ZIP"
# Same signature check as the DMG: Sparkle verifies this exact file, so it is
# the artifact that actually has to be Gatekeeper-accepting.
unzip -qo "$DIST_ZIP" -d /tmp/${APP}-dist-verify
spctl -a -t execute -vv "/tmp/${APP}-dist-verify/$APP.app"
rm -rf "/tmp/${APP}-dist-verify"

echo "Gatekeeper-clean DMG: $DMG"
echo "Sparkle enclosure (stapled, zipped): $DIST_ZIP"
