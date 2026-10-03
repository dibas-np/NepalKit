# Watch readiness evidence

Status: automated and native readiness evidence collected, 2026-10-02
Scope: the readiness gate before physical-device validation
Baseline: dataset 2.0.0 (Bikram Sambat 1975–2084; Gregorian 1918-04-13 through 2028-04-12)

## Gate status

| Gate | Status |
| --- | --- |
| Implementation start (host baseline) | Passed |
| Ready for physical validation (this record) | Automated, build and watchOS-26-runtime checks pass; the interactive native-rendering checks (full-color/accented modes, on-face glyph fit, real Dynamic Type and scrolling, VoiceOver) and every physical observation remain explicit session obligations — the gate's automated portion is what this record claims |
| Physical validation | Not performed |
| Final feature acceptance | Blocked: projected 2084 is provisional under the dataset-readiness policy and does not satisfy ADR-0001; not an implementation or validation blocker |

## Toolchain and settings

| Item | Value |
| --- | --- |
| Xcode | 27.0 (27A266a) |
| Swift | Apple Swift 6.4 (swiftlang-6.4.0.34.1) |
| watchOS SDK | 27.0 (deployment floor watchOS 26.0 — SDK compilation is not minimum-runtime evidence) |
| watchOS Simulator runtime used for tests | watchOS 26.0 (26.0 – 23R353) |
| macOS floor (unchanged) | 26.6 |
| Language mode / concurrency | `SWIFT_VERSION = 6.0`, `SWIFT_APPROACHABLE_CONCURRENCY = YES`, `SWIFT_UPCOMING_FEATURE_MEMBER_IMPORT_VISIBILITY = YES` |
| Actor isolation | `MainActor` default on the Watch app and tests; `nonisolated` default on the complication extension (pure provider logic independent of the main actor) |
| Dataset | `CalendarDataset.v2` version 2.0.0, compiled Swift table shared by all targets; BS 2084 is provisional development/testing data (separately blocks final acceptance) |
| Bundle identities | container `com.dibas.NepalKit.NepalKitWatch`; Watch app `…NepalKitWatch.watchkitapp`; extension `…watchkitapp.NepalKitComplications`; tests `com.dibas.NepalKit.NepalKitWatchTests` |
| Signing | Team `CA89X9954L`, automatic; device-architecture Watch app and extension are signed with the team identity (codesign inspection) |

## Commands and results

All commands run from the repository root on 2026-10-02.

### Automated tests

| Suite | Command | Destination | Result |
| --- | --- | --- | --- |
| Core (host) | `cd NepalKitCore && swift test` | macOS host (macOS 27.0 SDK) | 87 tests, 18 suites passed |
| Watch app + extension | `xcodebuild test -project NepalKit.xcodeproj -scheme "NepalKitWatch Watch App" -destination 'platform=watchOS Simulator,name=Apple Watch SE 3 (40mm),OS=26.0'` | watchOS 26.0 Simulator | 49 tests, 7 suites passed |
| Watch, second case size | same, `-destination 'platform=watchOS Simulator,name=Apple Watch Ultra 3 (49mm),OS=26.0'` | watchOS 26.0 Simulator | 49 tests, 7 suites passed |
| macOS regression | `xcodebuild test -project NepalKit.xcodeproj -scheme NepalKit -destination 'platform=macOS'` | macOS host | 167 tests, 24 suites passed |
| Strict lint | `./scripts/swiftlint.sh lint --strict` | host | 0 violations, 0 serious in 117 files (run before each commit and re-run at review) |

The watch suites run on the watchOS 26.0 runtime itself — this is watchOS 26 execution, not merely SDK 27 compilation. Suites cover: the resolved-day contract (endpoints, both boundaries, Gregorian progression past them, invalid input and broken-dataset errors distinct from boundaries, midnight and timezone anchoring), display/speech components and firm copy, the fourteen-day timeline (entry zero at the original reading, successive NPT midnights, future-only 24-hour spacing, entry into support, after-maximum progression, no duplicated boundary, the fifteen-entry terminal case), failure policy (first/intermediate/terminal failures, prefix retention, unknown activation falling back to one original-instant error, exact `.after(error activation + 15 min)` requests, `.atEnd` for successful and boundary timelines), snapshot/preview/placeholder contracts with one-clock and zero-clock behavior, the Today lifecycle (activation, active midnight wake, deactivation cancellation, multi-day resume, repeated activation, clock-change handling), accessible label composition per family, and the fixture harness through production code.

### Builds

| Product | Command (abbreviated) | Result |
| --- | --- | --- |
| Watch app + extension + core, Simulator | `xcodebuild build -project NepalKit.xcodeproj -scheme "NepalKitWatch Watch App" -destination 'generic/platform=watchOS Simulator'` | Succeeded |
| Watch app + extension + core, device architecture | same with `-destination 'generic/platform=watchOS'` | Succeeded; universal `arm64 arm64_32`; signed `TeamIdentifier=CA89X9954L` |
| Watch-only container (stub) | `xcodebuild build -scheme NepalKitWatch -destination 'generic/platform=iOS Simulator'` | Succeeded (no iPhone UI; no executable beyond the container's own) |
| macOS app | `xcodebuild build -scheme NepalKit -destination 'platform=macOS'` | Succeeded |
| Release, fixture exclusion | Release build of the Watch app scheme, then inspection | See below |

### Containment and dataset access

Inspection of the built products (Debug-iphonesimulator and Debug-watchos):

```
NepalKitWatch.app
└── Watch/
    └── NepalKitWatch Watch App.app
        └── PlugIns/
            └── NepalKitComplications.appex
```

`WKApplication` and `WKWatchOnly` verified in the built Watch app's `Info.plist`; the extension's `Info.plist` carries `NSExtensionPointIdentifier = com.apple.widgetkit-extension`. Both Watch code targets link the single `NepalKitCore` product and its compiled `CalendarDataset.v2` — dataset access in each target context is exercised offline by the watchOS test suites (app-hosted tests and the extension's provider/builder tests against the same compiled table); no resource bundle, second table, or App Group exists.

### Fixture-harness exclusion (nondevelopment build)

Method: Release build of the Watch app scheme for watchOS Simulator, then `strings` and `nm` over both the Watch app and the extension binaries, searching for the fixture launch-argument names (`NepalKitFixture*`), and the fixture symbols (`WatchFixtureControl`, `TodayFixtures`, `ComplicationFixtures`).

Result: **zero matches in both binaries.** The harness compiles only under `NEPALKIT_WATCH_FIXTURES` (Watch targets' Debug configurations); no reachable fixture entry point exists in a nondevelopment build — the factories that would consume it are inside the same condition. Development availability is proven by the fixture tests executing the harness through production code on the watchOS 26 Simulator. To return to ordinary mode: build without the condition (Release, or remove it from the Debug configuration) and launch without arguments.

### Warnings

| Warning | Assessment |
| --- | --- |
| `appintentsmetadataprocessor: Metadata extraction skipped, no AppIntents.framework dependency found` (Watch builds) | Benign: the Watch products intentionally declare no App Intents |
| The Watch app's asset catalog declares a universal watchOS 1024×1024 app icon slot with no image yet | Recorded gap: icon art is a product decision and does not block development-signing or validation; required before any future distribution effort |

## Floor ratification (2026-10-04)

The watchOS deployment floor remains **26.0** by user decision. A cross-session change had raised it to 26.6; the restore keeps every Watch product at 26.0 and the floor gate reports consistent floors (macOS 26.6, watchOS 26.0, package floor 26). The watch suite passes on the watchOS 26.0 Simulator runtime after the restore, so this record's 26.0-runtime execution claims stay reproducible. The device observations of the SE 2 running watchOS 26.6 are unaffected — a device above the floor.

## Recorded risks carried forward (unchanged by a green run)

- The 31 classified source/month comparison pairs (25 unique months) establish recorded arbitration, not independent correctness of every month. The BS 2004 Poush/Magh gap remains unresolved inherited risk with an unrecoverable rationale; passing round trips and pinned comparisons do not remove it.
- Projected BS 2084 is provisional development/testing data. It blocks **final feature acceptance** until an ADR-0001-compliant dataset ships; it does not block implementation, this readiness record, or device validation.
- Parser and pinned-source checks were not rerun: no dataset or data-tooling change is part of this work.
- Spoken output is a platform rendering property; the transformation is unit-tested (`SpokenDateTests`), and on-device VoiceOver behavior is a physical-session obligation because visual Devanagari digits intentionally differ from Latin-digit speech.

## Remaining obligations of the physical session

Interactive checks that automated runs cannot honestly substitute: complication rendering in full-color and accented modes on real faces, native glyph fit for the longest canonical month names (including combining marks) in actual family slots, large-text and Today scrolling behavior under real Dynamic Type, tap-to-Today per family, offline/phone-unavailable operation, alternate-timezone behavior, activation refresh, the real Nepal-midnight transition outside the debugger, and VoiceOver. The checklist and worksheet live in [physical-validation.md](physical-validation.md).

## 2026-10-03 signed-build refresh

The current Debug and Release Watch app and embedded extension rebuilt successfully for device architecture. Signatures, profile authorization, certificate membership/expiry, containment and Release fixture exclusion were inspected. See the [signed-build refresh](signed-build-refresh-2026-10-03.md) for artifact paths, exact commands and observed expiry dates. This refresh does not complete physical observations or rerun Watch runtime tests.

## Dataset 2.0.1 follow-up

The user-approved provisional 2084 row is now updated in the shared core, with
regression/native-runtime checks and a refreshed signed Release artifact. See
the [provisional dataset update](provisional-2084-update.md) for exact values,
results and current fingerprints. Historical dataset 2.0.0 evidence above is
preserved as history. The projection still does not clear ADR-0001 acceptance.
