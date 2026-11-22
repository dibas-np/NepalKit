#!/bin/zsh

# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Dibas Sigdel
set -euo pipefail

ROOT="${0:A:h:h}"
APP=NepalKit
WORK="$(mktemp -d "${TMPDIR:-/tmp}/NepalKit-release.XXXXXXXX")"
ARCHIVE="$WORK/$APP.xcarchive"
EXPORT_DIR="$WORK/${APP}-export"
APP_PATH="$EXPORT_DIR/$APP.app"
DMG="$WORK/$APP.dmg"
NOTARY_ZIP="$WORK/${APP}-for-notary.zip"

BACKGROUND=dmg-background@2x.png
DMG_LAYOUT="$WORK/${APP}-layout.dmg"
DMG_LAYOUT_MOUNT="/Volumes/${APP}-layout-${WORK:t}"
DMG_LAYOUT_SIZE=300m
DMG_LAYOUT_DEVICE=
MNT="/Volumes/${APP}-release-check-${WORK:t}"

DIST_ZIP=
LS_CLEANUP_FAILED=0

unregister_launchservices() {
    local bundle unregister_result=0
    for bundle in "$APP_PATH" "$DMG_LAYOUT_MOUNT/$APP.app" "$MNT/$APP.app" \
                  "$WORK/${APP}-dist-verify/$APP.app"; do
        [[ -e "$bundle" ]] || continue
        "$ROOT/scripts/unregister-launchservices.sh" "$bundle" || unregister_result=1
    done
    return "$unregister_result"
}

cleanup() {
    if ! unregister_launchservices; then
        LS_CLEANUP_FAILED=1
    fi
    diskutil unmount "$MNT" >/dev/null 2>&1 || true
    diskutil unmount "$DMG_LAYOUT_MOUNT" >/dev/null 2>&1 || true
    [[ -n "$DMG_LAYOUT_DEVICE" ]] && diskutil eject "$DMG_LAYOUT_DEVICE" >/dev/null 2>&1
    if (( LS_CLEANUP_FAILED )); then
        echo "release workspace retained for LaunchServices cleanup: $WORK" >&2
        echo "retry the exported app at $APP_PATH; remount retained disk images at their original mount points" >&2
    else
        rm -rf "$WORK"
    fi
    return 0
}
trap cleanup EXIT
trap 'cleanup; exit 129' HUP
trap 'cleanup; exit 130' INT
trap 'cleanup; exit 143' TERM

NOTARY_PROFILE="${NOTARY_PROFILE:-NepalKit-notary}"

PROJECT_TEAM="$(grep -o 'DEVELOPMENT_TEAM = [A-Z0-9]*;' "$ROOT/$APP.xcodeproj/project.pbxproj" \
    | sed 's/DEVELOPMENT_TEAM = //; s/;//' | sort -u || true)"
if [[ -z "$PROJECT_TEAM" || "$PROJECT_TEAM" == *$'\n'* ]]; then
    echo "the project must state exactly one DEVELOPMENT_TEAM; found: ${PROJECT_TEAM:-none}"
    exit 2
fi
TEAM_ID="${TEAM_ID:-$PROJECT_TEAM}"
if [[ "$TEAM_ID" != "$PROJECT_TEAM" ]]; then
    echo "TEAM_ID=$TEAM_ID does not match the project's DEVELOPMENT_TEAM=$PROJECT_TEAM."
    exit 2
fi

NOTARY_ARGS=(--keychain-profile "$NOTARY_PROFILE")

echo "notary credentials: keychain profile '$NOTARY_PROFILE'"


IDENTITY="$(security find-identity -v -p codesigning \
    | grep -o "Developer ID Application: .* ($TEAM_ID)" | awk 'NR == 1 { print }' || true)"
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

xcodebuild -project "$ROOT/$APP.xcodeproj" -scheme "$APP" \
    -destination 'generic/platform=macOS' -configuration Release \
    CODE_SIGN_STYLE=Manual CODE_SIGN_IDENTITY="$IDENTITY" DEVELOPMENT_TEAM="$TEAM_ID" \
    -archivePath "$ARCHIVE" archive
xcodebuild -exportArchive -archivePath "$ARCHIVE" \
    -exportPath "$EXPORT_DIR" -exportOptionsPlist "$WORK/${APP}-ExportOptions.plist"

codesign --verify --deep --strict --verbose=2 "$APP_PATH"
codesign -dv --verbose=4 "$APP_PATH" 2>&1 | tee "$WORK/${APP}-codesign.txt"
grep -q "flags=.*runtime" "$WORK/${APP}-codesign.txt" || {
    echo "hardened runtime flag missing from signature"
    exit 1
}

python3 "$ROOT/scripts/verify-release-product.py" "$APP_PATH" \
    --project "$ROOT/$APP.xcodeproj/project.pbxproj" \
    --entitlements "$ROOT/$APP/$APP.entitlements"

ditto -c -k --sequesterRsrc --keepParent "$APP_PATH" "$NOTARY_ZIP"
xcrun notarytool submit "$NOTARY_ZIP" "${NOTARY_ARGS[@]}" --wait
xcrun stapler staple "$APP_PATH"
xcrun stapler validate "$APP_PATH"
spctl -a -t execute -vv "$APP_PATH"
echo "app notarized and stapled: $APP_PATH"

# Finder only writes the window layout (.DS_Store) onto a mounted, writable
# volume, so the layout is built on a read-write HFS+ image and then converted
# to UDZO.
HDIUTIL_LOG="$WORK/${APP}-hdiutil.log"
hdiutil_run() {
    hdiutil "$@" 2>"$HDIUTIL_LOG" || {
        echo "hdiutil $1 failed:" >&2
        cat "$HDIUTIL_LOG" >&2
        exit 1
    }
    grep -v "is deprecated" "$HDIUTIL_LOG" >&2 || true
}

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
DMG_LAYOUT_DEVICE=$(diskutil image attach "$DMG_LAYOUT" --mountPoint "$DMG_LAYOUT_MOUNT" --plist \
    | plutil -extract system-entities.0.dev-entry raw -o - -)

mkdir -p "$DMG_LAYOUT_MOUNT/.background"
ditto "$APP_PATH" "$DMG_LAYOUT_MOUNT/$APP.app"
ln -s /Applications "$DMG_LAYOUT_MOUNT/Applications"
LAYOUT=$(swift "$ROOT/scripts/make-dmg-artwork.swift" "$DMG_LAYOUT_MOUNT/.background/$BACKGROUND" "$APP")
finder_run "$ROOT/scripts/dmg-layout.applescript" "${DMG_LAYOUT_MOUNT:t}" "$APP" \
    "$DMG_LAYOUT_MOUNT/.background/$BACKGROUND" "$LAYOUT"

rm -rf "$DMG_LAYOUT_MOUNT/.fseventsd"
# Unmount, then eject. A still-attached image makes the conversion fail with EBUSY.
unregister_launchservices
diskutil unmount "$DMG_LAYOUT_MOUNT"
diskutil eject "$DMG_LAYOUT_DEVICE"

rm -f "$DMG"
hdiutil_run convert "$DMG_LAYOUT" -format UDZO -o "$DMG"

xcrun notarytool submit "$DMG" "${NOTARY_ARGS[@]}" --wait
xcrun stapler staple "$DMG"

xcrun stapler validate "$DMG"

# Not mounted with nobrowse: Finder cannot read the window of a hidden volume.
diskutil image attach "$DMG" --mountPoint "$MNT" >/dev/null

finder_run "$ROOT/scripts/verify-dmg-layout.applescript" "${MNT:t}" "$APP" "$LAYOUT"

strings -a "$MNT/.DS_Store" | grep -q "$BACKGROUND" || {
    echo "the DMG window has no background picture: .DS_Store never names $BACKGROUND"
    exit 1
}
[[ -f "$MNT/.background/$BACKGROUND" ]] || {
    echo "the DMG window's background picture is not in the image"
    exit 1
}

spctl -a -t execute "$MNT/$APP.app"

open "$MNT/$APP.app"
launched=0
for _ in {1..15}; do
    if pgrep -f "$MNT/$APP.app/Contents/MacOS/$APP" >/dev/null; then launched=1; break; fi
    sleep 1
done
[[ $launched == 1 ]] || { echo "app did not launch from mounted DMG"; exit 1; }
pkill -f "$MNT/$APP.app/Contents/MacOS/$APP" || true

VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" \
    "$APP_PATH/Contents/Info.plist")
DIST_ZIP="$WORK/${APP}-${VERSION}.zip"
rm -f "$DIST_ZIP"
ditto -c -k --sequesterRsrc --keepParent "$APP_PATH" "$DIST_ZIP"
unzip -qo "$DIST_ZIP" -d "$WORK/${APP}-dist-verify"
spctl -a -t execute -vv "$WORK/${APP}-dist-verify/$APP.app"
"${0:A:h}/unregister-launchservices.sh" "$WORK/${APP}-dist-verify/$APP.app"
rm -rf "$WORK/${APP}-dist-verify"

APPCAST_DIR="$WORK/${APP}-appcast-$VERSION"
rm -rf "$APPCAST_DIR"
mkdir -p "$APPCAST_DIR"
cp "$DIST_ZIP" "$APPCAST_DIR/"
"${0:A:h}/verify-appcast.sh" "$APPCAST_DIR" || {
    echo "appcast verification failed; refusing to report a publishable release"
    exit 1
}

python3 "$ROOT/scripts/update-changelog.py" "$APPCAST_DIR/appcast.xml"

OUT_DIR="$(mktemp -d "${TMPDIR:-/tmp}/NepalKit-release-output.XXXXXXXX")"
cp "$DMG" "$DIST_ZIP" "$APPCAST_DIR/appcast.xml" "$OUT_DIR/"
chmod 0444 "$OUT_DIR"/*

echo "Gatekeeper-clean DMG: $OUT_DIR/$(basename "$DMG")"
echo "Sparkle enclosure (stapled, zipped): $OUT_DIR/$(basename "$DIST_ZIP")"
echo "Signed appcast: $OUT_DIR/appcast.xml"
echo "Changelog updated: $ROOT/CHANGELOG.md"

unregister_launchservices || {
    LS_CLEANUP_FAILED=1
    echo "release hygiene failed: a run bundle is still registered with LaunchServices" >&2
    echo "re-run scripts/unregister-launchservices.sh on $APP_PATH and any retained mounted bundles before publishing" >&2
    exit 1
}
