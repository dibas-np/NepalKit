# Refreshed development-signed Watch build

Date: 2026-10-03
Revision: fec0ea8, including the existing uncommitted Watch icon change
Scope: fresh device-architecture Debug and Release builds, signing/provisioning and nondevelopment fixture inspection

## Result

Both configurations built successfully with the Watch app scheme on Xcode 27.0 build 27A266a. Both contain the signed WidgetKit extension. This refresh prepares artifacts for physical validation; it does not install or launch them, rerun Watch tests, or establish outstanding physical observations.

## Reproduce

```sh
xcodebuild build -project NepalKit.xcodeproj -scheme 'NepalKitWatch Watch App' \
  -configuration Debug -destination 'generic/platform=watchOS' \
  -derivedDataPath /tmp/nepalkit-watch-refresh-20261003

# Ordinary-path configuration with fixture controls excluded
xcodebuild build -project NepalKit.xcodeproj -scheme 'NepalKitWatch Watch App' \
  -configuration Release -destination 'generic/platform=watchOS' \
  -derivedDataPath /tmp/nepalkit-watch-refresh-20261003
```

The explicit command-line scheme/configuration/destination avoids dependence on Xcode's remembered GUI selection. Signing used the existing automatic-signing configuration; no account changes, provisioning-update option or distribution operation was needed.

## Artifacts

| Configuration | App |
| --- | --- |
| Debug | `/tmp/nepalkit-watch-refresh-20261003/Build/Products/Debug-watchos/NepalKitWatch Watch App.app` |
| Release | `/tmp/nepalkit-watch-refresh-20261003/Build/Products/Release-watchos/NepalKitWatch Watch App.app` |

Each app contains `PlugIns/NepalKitComplications.appex`. The Watch app has `WKWatchOnly = true`; the embedded extension declares `com.apple.widgetkit-extension`. Use the Watch app scheme and physical Watch destination for installation, not the packaging-container scheme.

## Inspection

For each configuration, the app and embedded extension passed individual `codesign --verify --deep --strict` checks. Embedded profiles were decoded in memory and checked against the signed application identity and team, including profile wildcard authorization. The extracted signing certificate matched a DeveloperCertificates entry in each profile. Both signed products allow development debugging and have only application identity, team identity and get-task-allow entitlements; no App Group or distribution capability was added. No credentials, provisioning device identifiers or certificate owner names are recorded.

| Item | App and extension |
| --- | --- |
| Team | CA89X9954L |
| Minimum watchOS | 26.0 |
| Executable architectures | arm64 and arm64_32 |
| Profile expiration UTC | 2027-10-02T19:02:44+00:00 |
| Profile expiration Nepal Time | 2027-10-03 00:47:44 +05:45 |
| Signing certificate expiration UTC | 2027-09-27T15:52:42+00:00 |
| Signing certificate expiration Nepal Time | 2027-09-27 21:37:42 +05:45 |

Both profiles and the certificate are unexpired at inspection. The certificate expires earlier than the profiles. These timestamps do not guarantee future account/certificate validity or installation on a particular device. Recheck at installation and before the real-midnight observation; re-sign/reinstall if needed. The generic seven-day Personal Team warning in the historical handoff is not the observed expiry of these artifacts.

Release nondevelopment inspection used `strings` and `nm` on both executables. There were zero matches for `NepalKitFixture`, `WatchFixtureControl`, `TodayFixtures` and `ComplicationFixtures`. The fixture-consuming factories are compile-condition isolated in the production source, and no fixture entry point was found by this inspection. Debug binaries also had no matches in this refresh; this build does not claim fixture availability.

### Artifact fingerprints

| Configuration/product | Executable SHA-256 |
| --- | --- |
| Debug: NepalKitWatch Watch App.app | `afe7b305647b2ee7d55e3896df556fd92d1ac97f3fd8a6ad4fd169190c4b5fb1` |
| Debug: NepalKitComplications.appex | `539d8f1513f0b875c581fac41d1a8863c6e315cf724fdf5b4b1ae52d4234a55e` |
| Release: NepalKitWatch Watch App.app | `d7e6929ea6fa8f23dad6a5cb75a06d368efaab97f4b43925264af9b6cf1d2f23` |
| Release: NepalKitComplications.appex | `51004ba12bec68a8fb05dab49cd0ed01097e57ba4db70acfbea2e17bf59bb5d2` |

## Logs and limits

- Debug build log: `/tmp/nepalkit-watch-refresh-20261003-build.log`.
- Release build log: `/tmp/nepalkit-watch-refresh-20261003-release.log`.
- Sanitized inspection output: `/tmp/nepalkit-watch-refresh-20261003-inspection.json`.
- Both logs contain the App Intents metadata-extraction warning because these Watch targets intentionally have no AppIntents dependency. No build error was reported.
- The existing icon working-tree change is included and preserved. No source, project or signing-setting changes were made.
- Device installation, VoiceOver rechecks, remaining native/family checks and the recorded ordinary-path midnight session remain pending.
- Projected Bikram Sambat 2084 still independently blocks final feature acceptance pending ADR-0001 compliance.

Related: [readiness evidence](readiness-evidence.md), [physical-validation checklist](physical-validation.md), and [execution/readiness review](../../.scratch/apple-watch-delivery/readiness-review.md).

## Dataset 2.0.1 follow-up

The user-approved provisional 2084 row is now updated in the shared core, with
regression/native-runtime checks and a refreshed signed Release artifact. See
the [provisional dataset update](provisional-2084-update.md) for exact values,
results and current fingerprints. Historical dataset 2.0.0 evidence above is
preserved as history. The projection still does not clear ADR-0001 acceptance.
