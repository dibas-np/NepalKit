#!/bin/zsh

# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Dibas Sigdel
# Release pipeline (ticket 08): archive, Developer ID export, DMG, notarize,
# staple, Gatekeeper-verify. Proves a Gatekeeper-clean DMG for public releases.
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
MACOSX_DEPLOYMENT_TARGET=$DEPLOYMENT_TARGET xcodebuild -project "$ROOT/$APP.xcodeproj" -scheme "$APP" \
    -destination 'platform=macOS' -configuration Release \
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

# DMG with an Applications shortcut for drag-install.
rm -rf "$STAGE"
mkdir -p "$STAGE"
cp -R "$APP_PATH" "$STAGE/"
ln -s /Applications "$STAGE/Applications"
rm -f "$DMG"
hdiutil create -volname "$APP" -srcfolder "$STAGE" -ov -format UDZO "$DMG"

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
cleanup() { hdiutil detach "$MNT" >/dev/null 2>&1 || true; }
trap cleanup EXIT
hdiutil attach "$DMG" -nobrowse -mountpoint "$MNT"
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

echo "Gatekeeper-clean DMG: $DMG"
