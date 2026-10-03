# Watch physical-validation handoff

Status: prepared, 2026-10-02
Scope: development-signed build preparation and the physical-device session worksheet for the Apple Watch SE 2 (watchOS 26) paired with iPhone 17 (iOS 27)
Related: [readiness evidence](readiness-evidence.md)

## Prepared artifact and reproduction

The readiness gate is satisfied for the automated/build checks. Reproduce the development-signed artifact from the repository root:

```sh
# Watch app + embedded complication extension, device architecture, signed
xcodebuild build -project NepalKit.xcodeproj -scheme "NepalKitWatch Watch App" \
    -destination 'generic/platform=watchOS'
```

Install via Xcode: open `NepalKit.xcodeproj`, select the **NepalKitWatch Watch App** scheme and the physical Watch destination, Product ▸ Run. For a distribution-shaped container (not needed for development install), the **NepalKitWatch** scheme builds the watch-only container at `NepalKitWatch.app/Watch/NepalKitWatch Watch App.app/PlugIns/NepalKitComplications.appex`.

| Signing item | Value / instruction |
| --- | --- |
| Team | `CA89X9954L`, automatic signing on the Watch app, extension and container |
| Entitlements | None beyond defaults — no App Group, no distribution capabilities |
| Identities | container `com.dibas.NepalKit.NepalKitWatch`; Watch app `…watchkitapp`; extension `…watchkitapp.NepalKitComplications` |
| Profile validity | Development profiles expire (Personal Team: seven days; also ten App IDs / three devices per platform). Schedule installation **and** the real-midnight observation inside the validity window; re-sign and reinstall beforehand if validity would lapse. Recheck current Personal Team limits at session time — they are Apple-account facts, not repository facts. |

Recorded during preparation: no credentials or device identifiers are stored in this document.

## Compatibility prechecks (read-only, done in planning, recheck at session)

- Xcode 27 supports watchOS deployment targets 9–27 and watchOS physical-device support from watchOS 10; the watchOS 26.0 floor and iOS 27 phone are inside the documented ranges.
- Apple lists the SE 2 among watches eligible for watchOS 26, pairing with iPhone 8 or later on iOS 16+.
- Unobserved at preparation — session confirmation fields: exact OS patch versions, SE 2 case size (40/44 mm), installed faces, actual provisioning status, operational pairing state. An identified incompatibility blocks the session; an unobservable detail is a gap to confirm, not a failure.

## Development harness (fixture) usage

Build and run with the Watch targets' Debug configurations (they carry `NEPALKIT_WATCH_FIXTURES`) and pass launch arguments in the scheme's Arguments Passed On Launch for one launch only — nothing persists:

| Argument | Effect |
| --- | --- |
| `-NepalKitFixtureScenario boundaryBefore` | Today before the supported range (1918-04-12) |
| `-NepalKitFixtureScenario boundaryAfter` | Today after the range (2028-04-13) |
| `-NepalKitFixtureScenario projected2084` | Today inside the provisional 2084 year |
| `-NepalKitFixtureScenario terminal` | Day +13 equals the dataset maximum → the fifteenth terminal entry |
| `-NepalKitFixtureScenario midnightApproach` | Today 5 minutes before an NPT midnight |
| `-NepalKitFixtureInstant <ISO-8601 Z>` | Any fixed instant |
| `-NepalKitFixtureFailAt <offset>` | Timeline resolution fails at that horizon offset (prefix retained, `.after` +15 min) |
| `-NepalKitFixtureError today` / `withoutContext` | Today resolution fails with / without Gregorian context |
| `-NepalKitFixtureFailActivation` | The next-midnight calculation fails, exercising the unknown-activation fallback |

The Today screen shows a `FIXTURE — …` banner while active. For the complication extension in Simulator, the same arguments can be supplied on the extension's scheme run. To return to ordinary mode for the real-midnight observation: build without the condition (Release, or remove it from the Debug configuration) and launch without arguments. Never change the device system date.

## Physical session checklist

1. **Setup.** Record exact OS patches and the SE 2 case size; confirm pairing readiness in Device Hub (pair iPhone first, then Watch; accept trust prompts; enable Developer Mode on both, including the restart confirmation; if Developer Mode is absent, initiate pairing first). Inspect Device Hub's reported readiness issues rather than inferring incompatibility.
2. **Install and launch.** Confirm account/team/identities and profile validity. Select the Watch app scheme and the physical Watch destination; require a clean build, install, and first launch of Today. Record the outcome and any actionable failure.
3. **Families.** Add the complication in the actual picker on the planned slots: Modular middle rectangular, Utility bottom inline, Infograph inner circular, Infograph outer corner. Record actual face/slot availability; resolve any coverage gap rather than claiming an unobserved slot. Another case size is covered in Simulator (49 mm recorded in the readiness evidence).
4. **Presentation.** Verify each tap opens current Today; canonical Nepali names, Devanagari digits, English Gregorian months, one weekday per date; native fit of the longest month names and combining marks (कात्तिक worst case) in every slot; large-text fallback and Today scrolling; full-color and accented legibility; VoiceOver announces Latin-digit full Bikram Sambat dates, one weekday, Gregorian context where presented, and support context on boundaries.
5. **Independence and travel.** Exercise offline and phone-unavailable operation in both the app and the complications. Change the device timezone with a known instant and confirm Nepal Time semantics; restore the timezone afterwards. Deactivate/reactivate across a day boundary and confirm immediate recomputation.
6. **Harness cases.** Through the clearly identified fixture banner: both dataset boundaries, the terminal-entry case, expected unavailable and genuine error states with/without Gregorian context, and an NPT transition. Confirm failure injection never renders as an ordinary boundary. Do not change the device system date.
7. **Real midnight.** Verify the development profile covers the session; re-sign/reinstall first if validity is uncertain. Build ordinary (non-fixture) mode and observe at least one real NPT midnight **outside the debugger**. Record the expected boundary behavior and the *observed* family refresh timing without asserting a 00:00:00 deadline or retry SLA; unexpected observations trigger investigation and, if warranted, an explicit evidence-backed scheduling decision.
8. **Record.** Fill the worksheet below per observation: build/dataset version, model/OS, face/family, supplied instant/NPT day/state, expected vs observed, pass/fail, outstanding issues.

## Observation worksheet

| # | Item | Expected | Observed | Pass/Fail | Notes |
| --- | --- | --- | --- | --- | --- |
| 1 | Device patches / case size | recorded fields | | | |
| 2 | Pairing + Developer Mode + install + first launch | Today appears | | | |
| 3 | Rectangular slot (Modular middle) | weekday + BS day/month + year/Gregorian line | | | |
| 4 | Inline slot (Utility bottom) | full BS day/month/year | | | |
| 5 | Circular slot (Infograph inner) | stacked BS day/month | | | |
| 6 | Corner slot (Infograph outer) | BS day + month/year label | | | |
| 7 | Tap-to-Today per family | Today, current NPT day | | | |
| 8 | Longest month/combining marks (कात्तिक) | no clipping or illegible fit | | | |
| 9 | Large text + Today scrolling | fallback composition, scrollable | | | |
| 10 | Full-color + accented rendering | states distinguishable without color | | | |
| 11 | VoiceOver | Latin-digit full BS speech; conditional Gregorian | | | |
| 12 | Offline + phone unavailable | both products answer | | | |
| 13 | Alternate device timezone | NPT semantics unchanged | | | |
| 14 | Deactivate/reactivate across a day | immediate recomputation | | | |
| 15 | Fixture: boundaryBefore / boundaryAfter | explicit unavailable copy + support context | | | |
| 16 | Fixture: projected2084 | renders via shared dataset; provisional | | | |
| 17 | Fixture: terminal | 15-entry timeline behavior visible | | | |
| 18 | Fixture: error with/without context | error copy; Gregorian only when resolved | | | |
| 19 | Real NPT midnight (ordinary build, no debugger) | date flips per family; observed timing recorded | | | |
| 20 | Profile validity covered the session | yes/no; re-sign performed | | | |

## Session log

### 2026-10-03 — first install and observation (SE 2, 44 mm, watchOS 26.6)

Setup: Developer Mode on; paired install via the **NepalKitWatch Watch App** scheme after an initial wrong-scheme attempt (running the container scheme produced the `ITSWatchOnlyContainer` non-installable error and platform-mismatched destinations — the container scheme was then removed).

| Rows | Result |
| --- | --- |
| 1–2 | Pass: 44 mm, watchOS 26.6; first launch renders weekday, prominent Devanagari day, month/year, Gregorian line as expected; no fixture banner; date correct across a midnight boundary. |
| 5–6 | Pass: circular (Infograph inner) and corner (outer) slots added and rendering. |
| 7 | Pass: tap opens Today (circular, corner verified; others pending re-check). |
| 3 | **Defect**: rectangular slot clipped the weekday (top) and Gregorian line (bottom). Fixed in code — weekday stepped down to caption2; re-check pending. |
| 5 | **Defect**: circular stack sat slightly low optically. Fixed — small optical lift applied; re-check pending. |
| 4/9 | **Defect**: the large-text fallbacks never triggered — the watchOS Text Size slider's maximum stops below the accessibility size categories, so `isAccessibilitySize` never fired on-device. Fixed — fallbacks now switch from xxLarge; re-check pending. Today's scrolling fallback itself worked once reached. |
| — | **Gap**: no app icon (empty appiconset). Fixed — the shared Icon Composer `AppIcon.icon` now ships with the Watch app; on-device appearance re-check pending. |

### 2026-10-03 — second iteration

| Item | Result |
| --- | --- |
| Rectangular (two-line, weekday at caption2) | **Still clipped** — three Devanagari-bearing rows do not fit; reworked again: day/month alone on line one, weekday · year on line two, the optional Gregorian piece leaving the visuals (label follows). Re-check pending. |
| Circular | Fixed and confirmed. |
| App icon | Fixed and confirmed. |
| Large text in app | Fallback appears from the top slider steps as designed; text scaling within the top steps is subtle by design. Scaling confirmed when the slider returns below xxLarge (hero returns smaller) — pending user confirmation. |
| VoiceOver | Two findings: list separators announced aloud ("comma") — fixed, labels now join with line breaks; and the Devanagari month name was skipped in speech (user heard "day and year" where day+month is shown), consistent with the documented platform-side speech risk when the active voice does not cover the script. The spec's decision to keep canonical Nepali names in speech stands; transliterated speech would need an explicit spec decision. |
| Independence (offline/timezone) | Reported working. |

### 2026-10-03 — third iteration

| Item | Result |
| --- | --- |
| Rectangular (two-line: day/month over weekday · year) | Pass — fits without clipping or truncation, confirmed on the 44 mm slot. |
| VoiceOver speech decision | The user approved switching spoken month and weekday names to transliterated ("17 Ashoj 2083", "Sunday"), because the watch's active voice skips Devanagari month names. Visuals keep the canonical Devanagari script. Implemented in the core display builder; on-device re-check pending the next install. |

### 2026-10-03 — fixture batch

| Row | Result |
| --- | --- |
| 15–18 | Pass (app surface): both boundaries, projected 2084, terminal, and error with/without context all render through production code, each launch clearly banner-identified. |
| 8 (partial) | The on-device fixture instant cannot reach the complication extension process — launch arguments belong to the app, and no shared store is permitted (no App Group). The corner's कात्तिक curved-label fit is therefore judged via the new native previews ("Corner — longest month") now, with the natural occurrence on 18 October 2026 as the on-device confirmation. |

## Gates after this session

Physical evidence from this worksheet establishes **device validation**. **Final feature acceptance** additionally requires an ADR-0001-compliant shared dataset (projected 2084 currently blocks it independently). App Store/TestFlight and public distribution remain a separate follow-on effort; nothing here prepares or claims them.

## 2026-10-03 signed-build refresh

The current Debug and Release Watch app and embedded extension rebuilt successfully for device architecture. Signatures, profile authorization, certificate membership/expiry, containment and Release fixture exclusion were inspected. See the [signed-build refresh](signed-build-refresh-2026-10-03.md) for artifact paths, exact commands and observed expiry dates. This refresh does not complete physical observations or rerun Watch runtime tests.

### 2026-10-03 — refreshed Release build confirmation

After the refreshed signed build and physical-install instructions, the user confirmed: "yeah everything works in release". Record this as user-reported successful Release installation and operation on the reference Watch. No installation blocker was reported.

This broad confirmation does not separately enumerate VoiceOver output, every face/family/text-size combination, profile inspection on the installed device, or the expected/observed timing of an ordinary-path Nepal-midnight session. Those detailed worksheet observations remain unrecorded rather than being inferred from the general confirmation. Projected Bikram Sambat 2084 still independently blocks final feature acceptance pending ADR-0001 compliance.

## Dataset 2.0.1 follow-up

The user-approved provisional 2084 row is now updated in the shared core, with
regression/native-runtime checks and a refreshed signed Release artifact. See
the [provisional dataset update](provisional-2084-update.md) for exact values,
results and current fingerprints. Historical dataset 2.0.0 evidence above is
preserved as history. The projection still does not clear ADR-0001 acceptance.

### 2026-10-03 — additional user-reported validation

The user reports that the other requested physical checks have passed, while
asking how to perform activation refresh and identifying the real Nepal-midnight
observation as pending. Record this as user-reported completion of the remaining
layout/accessibility, offline, navigation and timezone checks; no per-case timing
or screenshots were supplied. Activation refresh (worksheet 14) remains pending
confirmation, and the ordinary-build real-midnight observation (worksheet 19)
remains pending. This report does not attest the provisional 2084 dataset.

For activation refresh, open Today shortly before Nepal midnight, note both
dates, press the Digital Crown to return to the face without force-quitting,
and reopen the existing app shortly after midnight. Today must show the new NPT
day without a manual refresh or relaunch. Reopening within the same day is a
lifecycle smoke check, not proof of stale-date correction across a day boundary.
Use the ordinary Release build without a debugger; the fixed-instant fixture
clock does not advance with real elapsed time and cannot prove this physical
transition by waiting.
