#!/bin/zsh
# Release pipeline (ticket 08): archive, Developer ID export, DMG, notarize,
# staple, Gatekeeper-verify. Proves a Gatekeeper-clean DMG for public releases.
#
# NOT YET PROVEN: needs a paid Apple Developer account. Provide credentials
# via env (APPLE_ID, APP_SPECIFIC_PASSWORD, TEAM_ID); without them the script
# stops after the checks step with instructions. Requires network to Apple.
#
# Usage (repo root): APPLE_ID=you@example.com APP_SPECIFIC_PASSWORD=xxxx \
#   TEAM_ID=XXXXXXXXXX scripts/package-release.sh
set -euo pipefail

ROOT="${0:A:h:h}"
APP=NepalKit
IDENTITY="Developer ID Application: ${TEAM_ID:-MISSING}"
ARCHIVE=/tmp/$APP.xcarchive
EXPORT_DIR=/tmp/${APP}-export
DMG=/tmp/$APP.dmg

[[ -n "${APPLE_ID:-}" && -n "${APP_SPECIFIC_PASSWORD:-}" && -n "${TEAM_ID:-}" ]] || {
    echo "missing credentials: set APPLE_ID, APP_SPECIFIC_PASSWORD, TEAM_ID"
    echo "create an app-specific password at https://account.apple.com"
    exit 2
}
security find-identity -v -p codesigning | grep -q "$TEAM_ID" || {
    echo "no Developer ID identity for team $TEAM_ID in this keychain"
    exit 2
}

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

xcodebuild -project "$ROOT/$APP.xcodeproj" -scheme "$APP" \
    -destination 'platform=macOS' -configuration Release \
    -archivePath "$ARCHIVE" archive
xcodebuild -exportArchive -archivePath "$ARCHIVE" \
    -exportPath "$EXPORT_DIR" -exportOptionsPlist /tmp/${APP}-ExportOptions.plist

rm -f "$DMG"
hdiutil create -volname "$APP" -srcfolder "$EXPORT_DIR/$APP.app" \
    -ov -format UDZO "$DMG"

xcrun notarytool submit "$DMG" --apple-id "$APPLE_ID" \
    --password "$APP_SPECIFIC_PASSWORD" --team-id "$TEAM_ID" --wait
xcrun stapler staple "$DMG"
spctl -a -t open --context context:primary-signature -v "$DMG"
echo "Gatekeeper-clean DMG: $DMG"
