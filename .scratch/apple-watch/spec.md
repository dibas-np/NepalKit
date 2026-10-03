# NepalKit Apple Watch

Status: ready-for-agent
Labels: ready-for-agent
Review: accepted for implementation planning
Scope: specification and implementation tickets through readiness for physical-device validation
Date: 2026-10-02

## Problem Statement

NepalKit users can see Today on their Mac but cannot glance at the Bikram Sambat date on an Apple Watch. They need readable complications and a simple Today screen that remain correct according to Nepal Time, work offline, and distinguish an expected range boundary state from an actual calculation failure. A date outside the supported range must never appear as a fabricated date or a frozen last supported date.

The engineering team needs an accepted, testable handoff that defines the Watch feature and the development build/signing requirements for physical-device validation. macOS v1 is already shipped; its release gate is satisfied.

## Solution

Plan a standalone Watch-only SwiftUI app targeting watchOS 26.0 or later and an embedded WidgetKit extension supporting accessoryRectangular, accessoryInline, accessoryCircular and accessoryCorner. Each complication opens the read-only Today screen, showing the full Bikram Sambat date and corresponding Gregorian date for the Nepal Time day.

Both products use NepalKitCore and its existing shared compiled dataset. Display canonical Nepali names and Devanagari digits, with English Gregorian month names and complete accessible speech. Prepare deterministic tests, native layout checks and a development-signed app/extension for the user's Apple Watch SE 2 on watchOS 26, paired with iPhone 17 on iOS 27.

This spec is a planning deliverable. It defines future implementation and validation obligations; its ready-for-agent status does not authorize implementation execution in this planning effort.

## User Stories

1. As an Apple Watch user, I want to glance at Today in Bikram Sambat, so that I can check the date without opening my Mac.
2. As an Apple Watch user, I want a rectangular complication, so that I can see a detailed date in a larger slot.
3. As an Apple Watch user, I want an inline complication, so that I can place the date in a text slot.
4. As an Apple Watch user, I want a circular complication, so that I can see day and month in a compact slot.
5. As an Apple Watch user, I want a corner complication, so that I can use a corner slot on a compatible face.
6. As an Apple Watch user, I want tapping any complication to open Today, so that I can read the complete date.
7. As an Apple Watch user, I want Today as the default launch destination, so that the app opens directly to its useful information.
8. As an Apple Watch user, I want the full Bikram Sambat date on Today, so that I can read day, month and year together.
9. As an Apple Watch user, I want the corresponding Gregorian date, so that I can relate Today to other calendars.
10. As an Apple Watch user, I want one weekday for the resolved day, so that the two calendar representations do not repeat it.
11. As an Apple Watch user, I want canonical Nepali month and weekday names, so that the presentation matches the agreed display convention.
12. As an Apple Watch user, I want Devanagari digits, so that the visual date uses the agreed digit script.
13. As an Apple Watch user, I want English Gregorian month names, so that Gregorian presentation stays consistent with NepalKit.
14. As a traveling user, I want Today to follow Nepal Time regardless of device timezone, so that travel does not change the Nepal date.
15. As an Apple Watch user, I want date information offline, so that connectivity does not determine whether I can read Today.
16. As an Apple Watch user, I want the feature to work without my Mac or phone being available, so that the Watch remains useful on its own.
17. As an Apple Watch user, I want active Today to refresh at the next Nepal midnight, so that it does not retain yesterday's date during use.
18. As an Apple Watch user, I want Today to recompute when I return to the app, so that it recovers after inactive days.
19. As an Apple Watch user, I want Today to respond to significant clock changes, so that an active session can correct its date and refresh schedule.
20. As an Apple Watch user, I want future complication entries scheduled at Nepal midnight, so that calendar progression follows Nepal Time.
21. As an Apple Watch user, I want an explicit range boundary state, so that an unsupported Bikram Sambat date is never fabricated.
22. As an Apple Watch user, I want supported-range context where available, so that I understand why Bikram Sambat is unavailable.
23. As an Apple Watch user, I want Gregorian information to remain available at a range boundary, so that the screen still answers what it can.
24. As an Apple Watch user, I want a calculation failure identified separately, so that a defect is not misrepresented as an ordinary range boundary.
25. As an Apple Watch user, I want the last supported date to end with its Nepal Time day, so that a complication does not conceptually extend that date beyond validity.
26. As a large-text user, I want layouts to preserve primary day/month information, so that the complication remains useful without clipping.
27. As a large-text user, I want Today to use full date lines and scrolling when necessary, so that all date information remains readable.
28. As a VoiceOver user, I want complete Bikram Sambat speech with Latin digits and the full year, so that compact visuals do not omit accessible information.
29. As a VoiceOver user, I want Gregorian speech when that information is presented, so that I can hear the same context as a sighted user.
30. As an Apple Watch user, I want supported, boundary and error states distinguishable without color, so that rendering modes do not obscure meaning.
31. As an Apple Watch user, I want Nepali text and combining marks to fit native complication geometry, so that names remain legible.
32. As a developer, I want deterministic previews and neutral placeholders, so that samples are stable and placeholders do not imply a real Today.
33. As a developer, I want injectable instants and failure points through production logic, so that boundary and failure cases are reproducible without changing the system clock.
34. As a developer, I want the fixture controls absent from nondevelopment builds, so that testing controls cannot become product behavior.
35. As a developer, I want one shared compiled calendar dataset, so that Watch and Mac do not maintain conflicting tables.
36. As a maintainer, I want Mac regression evidence for shared changes, so that Watch integration preserves existing functionality.
37. As a validator, I want a prepared development-signed app and extension, so that physical-device validation can begin with a usable artifact.
38. As a validator, I want compatibility and provisioning requirements checked during preparation, so that known deployment blockers are caught early.
39. As a validator, I want all four families checked on the SE 2 and another case size in Simulator, so that layout evidence covers the required placements and size variation.
40. As a validator, I want profile validity to cover an actual Nepal-midnight observation, so that an expired installation does not invalidate the session.
41. As a maintainer, I want provisional data and historical evidence gaps documented, so that a passing implementation is not mistaken for independently verified calendar data.
42. As a maintainer, I want planning, implementation readiness, physical validation and final feature acceptance separated, so that each completion claim has the appropriate evidence.

## Implementation Decisions

- Target watchOS 26.0 or later. Preserve macOS 26.6 app compatibility and existing package compatibility. Use Swift 6.4 or later, Swift 6 language mode and strict concurrency. SDK compilation must respect the minimum OS and is not minimum-runtime evidence.
- Use Watch-only SwiftUI packaging with the template's iOS stub, no iPhone executable/UI, and an embedded watchOS WidgetKit extension. Do not add a legacy WatchKit code extension. Verify containment, extension safety, identities and actor isolation using current tooling.
- Link NepalKitCore into both Watch code targets. Retain the compiled CalendarDataset table; no resource migration, decoder, App Group or separately maintained Watch table is needed.
- The passing host tests are sufficient to begin a future implementation effort. Watch compilation, shared-dataset access in both target contexts and watchOS-relevant provider/calendar validation are implementation acceptance obligations.
- Core owns a Sendable resolved-day value containing one Gregorian civil day, one canonical weekday, and supported Bikram Sambat or an explicit before/after range boundary state. Invalid inputs, failed dataset assumptions and unexpected calculations are distinct errors.
- Reuse GADay, BSDay, CalendarDataset, conversions, todayAD(now:), nextNPTMidnight(after:) and canonical formatting. Resolve the Nepal Time Gregorian day once from a supplied instant. Gregorian day progression remains possible outside the supported range. Validate civil inputs; never infer a boundary merely from a nil conversion.
- Core owns calendar display components and complete speech. Watch display uses fixed canonical Nepali names and Devanagari digits; Gregorian month names stay English. Speech uses Latin digits, canonical Nepali names, one weekday and the complete Bikram Sambat year.
- Inject a small target-owned time function. Read it once per operation and pass the resulting instant into deterministic calculations. No clock protocol is required. Core does not acquire wall-clock time; views do not resolve dates.
- The extension owns timeline assembly, activation timestamps, horizon and reload policy. Use StaticConfiguration and a thin TimelineProvider adapter; no configurable App Intent is required. Complete each framework callback exactly once and use async APIs where available.
- Successful construction produces fourteen independently resolved Gregorian-day entries from Today through day +13, including ordinary boundary entries. Entry zero activates at the original clock reading. Future entries activate at successive Nepal midnights; only future-midnight intervals are twenty-four hours apart.
- If day +13 is the maximum supported Gregorian day, append exactly one range boundary entry at day +14's Nepal midnight. Fifteen total entries are valid in this case. If the maximum occurs earlier, the normal horizon already contains its following boundary; do not duplicate it. Before-minimum and after-maximum Today still generate the fourteen-day Gregorian sequence.
- At the first calculation failure, retain the valid prefix, append a distinct error at that day's intended activation, then stop. If the activation cannot be calculated, discard the prefix and return one error at the original clock reading. Apply the same rules to the conditional extra entry. Never fabricate timestamps or calendar values.
- Successful timelines, including range boundaries, use .atEnd. Calculation-error timelines request .after(errorEntryActivation + 15 minutes), using the original reading for the fallback entry. There is no second clock read, exact reload guarantee or promised recovery interval. A different policy requires an explicit decision.
- Ordinary snapshots resolve actual Today through core with one clock reading. Preview snapshots use fixed instants/days whose displayed values are generated through core. Placeholders neither read the clock nor resolve Today; use neutral or redacted representative content. Snapshot errors remain errors, not boundary states or fabricated samples.
- The Watch app contains only the read-only Today screen. Complication taps and app launch open Today; no routing feature is needed solely for those taps.
- Own a @MainActor @Observable Today model with @State. Compute on launch/activation, schedule cancellation-aware active refresh at the next Nepal midnight, cancel on inactivity and recompute immediately on reactivation. Repeated activation must not duplicate work. No polling or persistence is needed.
- While active, observe Date.SystemClockDidChangeMessage or its interoperating notification through a concurrency-safe adapter. Cancel stale work, read time once, resolve and reschedule. Own observation with the lifecycle. At scheduled wake recompute using current time. A missed signal may leave the active display stale until wake/activation, which provides corrective recomputation.
- Use the accepted Day-first composition. Rectangular shows one weekday and day/month, with year and optional Gregorian detail secondarily. Large text retains day/month then year and removes weekday/Gregorian first.
- Inline normally shows day/month/year; large text visually retains day/month while accessible speech retains the full year. Circular uses stacked day/month. Corner prioritizes day with month/year in the native widgetLabel. Today shows weekday, prominent day, month/year and full Gregorian date; oversized content becomes full date lines with scrolling.
- Use semantic text styles and deterministic fallbacks rather than truncation or aggressive shrinking. Verify the longest canonical month representation, combining marks, glyph bounds, full-color/accented modes and accessibility. Color alone cannot distinguish states.
- Boundary copy is "Bikram Sambat unavailable" or compact "Unavailable". Failure copy is "Date calculation failed" or compact "Error". Include applicable support and Gregorian context where space allows; preserve Gregorian information on errors only when it was successfully resolved. Accessible boundary descriptions retain support context even when visuals cannot fit it.
- Derive exact supported bounds from the dataset. First/last supported Bikram Sambat years are presentation context, not authoritative interval definitions. Never extrapolate or silently freeze the final supported date.
- The development harness controls instants, scenario selection and failure points through production resolver, timeline builder and views. It does not control expected calendar outputs, maintain another oracle or provide parallel mock implementations. Isolate it at compile time/build configuration, make active use identifiable, and exclude reachable entry points from nondevelopment builds. No product settings or persistence are added.
- Prepare unique template-compatible bundle identifiers, a common chosen development team, automatic signing and verified app/embedded-extension signatures, profiles and required entitlements. Retain packaging-stub requirements. Do not add distribution capabilities.
- During preparation, check available model/OS patches, Xcode/platform support and readiness information for the SE 2 on watchOS 26 paired with iPhone 17 on iOS 27. Known incompatibility blocks preparation. Unobservable details remain recorded gaps for session confirmation; operational pairing/install is not a readiness prerequisite.
- Local development does not require a paid membership. Recheck current Personal Team limits, profile expiration and signing behavior during implementation. Schedule installation and the real Nepal-midnight observation within validity; include re-sign/reinstall if necessary. Never record credentials or device identifiers in handoff evidence.
- Readiness for physical validation requires passing automated/native checks and a prepared development-signed Watch app with embedded extension. Pairing, trust, Developer Mode, installation and first launch begin the physical session. An unsigned build is not evidence of the signed-artifact gate.
- The required physical reference is the SE 2 for all four families, with another case size in Simulator. Planned placements are Modular middle rectangular, Utility bottom inline, and Infograph inner circular/outer corner. Confirm actual placements and resolve coverage gaps. A second physical Watch and always-on-display checks are optional.
- Future physical validation includes VoiceOver, large text, offline/phone-unavailable operation, complication-to-Today navigation, alternate device timezone, activation refresh and at least one actual Nepal-midnight transition outside the debugger. Record expected boundary and observed WidgetKit behavior without promising visible refresh precisely at midnight.
- Dataset 2.0.0 currently spans Bikram Sambat 1975 through 2084, corresponding to Gregorian 1918-04-13 through 2028-04-12. These are baseline facts, not production range constants. Projected 2084 is provisional development/testing data and does not satisfy ADR-0001. It blocks final feature acceptance, not implementation start or device validation. No data remedy or ADR amendment is selected here.
- The recorded discrepancy baseline is 31 source/month comparison pairs over 25 unique months across nine years, all within the shared range. Twenty-four pairs/eighteen months have recorded arbitration, two pairs/two months are the unresolved 2004 Poush/Magh historical gap, and five pairs/five months concern projected 2084. Month disagreements can affect later Gregorian mappings; matching year totals do not prove month correctness. Carry the 2004 gap as accepted inherited risk, not independently verified data or a new handoff blocker.
- Released Mac source already exposes projected 2084. This is a released-source conclusion, not a fresh runtime examination of the public binary. Preserve Mac functionality during integration without claiming ADR compliance or freezing the shared dataset against separately versioned, reviewed remediation. Do not create a Watch-specific cap or fork.

## Testing Decisions

- Test observable results at the highest useful contracts: supplied-instant/civil-day resolution, provider entry points and timeline output, Today lifecycle/state, and production presentation. Reuse existing conversion/time seams. Keep deterministic scheduling/failure controls small; do not introduce a broad abstraction or assert private implementation structure.
- These seams were explicitly accepted in the prior architecture and verification reviews. No additional seam interview is needed. Existing core tests provide prior art for full-range round trips, authoritative anchored dates, month/year boundaries, weekdays, formatting, Nepal-midnight behavior and timezone independence.
- Preserve independent authoritative anchors alongside consistency checks. Do not regenerate all expected results through the code under test, manufacture historical fixtures, or describe passing round trips/source comparisons as independent correctness of every month.
- Test core supported endpoints, both boundary directions, Gregorian progression, invalid civil inputs, unexpected failures, leap days, month/year transitions, one weekday, fixed visual formatting, complete speech and dataset-derived bounds.
- Test provider one-clock behavior, entry-zero activation, future Nepal-midnight activations and future-only spacing. Cover fourteen supported/unsupported entries, entry into support, maximum earlier in the horizon, maximum exactly at day +13 with day +14 added, and no duplicate boundary.
- Inject first, intermediate and extra-terminal calculation failures. Assert valid-prefix retention, stopping, a single original-instant error when activation fails, and no fabricated date context. Assert exact fifteen-minute requested error reload and successful .atEnd policy, without testing system-controlled delivery time as a guarantee.
- Test normal actual-Today snapshots, fixed core-generated previews, distinct snapshot failures, clock-free placeholders and exactly-once callbacks.
- Test Today launch/activation, active midnight, inactivity cancellation, multi-day resume, duplicate activation, forward/backward clock-change handling and missed-signal correction. Test supplied state rather than sleep duration or private task structure.
- Run shared domain/provider/model tests under watchOS-relevant conditions and a watchOS runner where supported. Record runtime versions. Host-only execution and SDK 27 compilation do not prove watchOS 26 execution.
- Build core, Watch app and extension for Simulator and device architecture. Demonstrate offline compiled-dataset access in both target contexts. Run appropriate existing Mac build/regression checks for shared changes and strict lint with zero new violations before committing.
- Native checks cover every family, another case size, long canonical names/combining marks, supported/boundary/error/placeholder states, large text, Today scrolling and full-color/accented rendering. Use unit tests for logic; UI tests are justified only when unit tests cannot verify the behavior.
- Exercise the development harness through production paths. Inspect a nondevelopment build and demonstrate no reachable harness launch route, control or configuration path. Record the inspection method; do not assume exclusion from a build flag alone.
- Prepare the future physical checklist for pairing, installation, all four placements, VoiceOver and behavioral observations. Profile validity must cover the real-midnight session. Actual physical observations are separate from automated readiness and are not claimed by this spec.
- Record exact commands, schemes, destinations, toolchain/SDK/runtime, deployment targets, concurrency/isolation, dataset version/provisional status, results and warnings. Run parser/pinned-source checks when data or associated tooling changes. Separate observed evidence from unverified external tooling/account claims.

## Out of Scope

- Implementation execution in this planning effort and completion of the physical-device session.
- App Store/TestFlight readiness, public distribution and release operations.
- Reopening the shipped macOS v1 release gate.
- Watch settings, conversion tools, persistence, network services, companion iPhone UI, Mac preferences or Mac-to-Watch synchronization.
- A second calendar engine/table, resource migration, App Group or third-party framework.
- Dataset sourcing/remediation, licensing resolution, independent verification of all historical months or changes to ADR-0001. These remain separately governed efforts.
- Guarantees of exact WidgetKit midnight rendering, reload timing or recovery time.

## Further Notes

The accepted detailed handoff remains [supporting material](handoff-details.md), including evidence classification, gate definitions and the complete physical-device checklist. The [planning map](map.md) is closed and every decision child is resolved. The [review response](review-response.md) records the accepted corrections. Human acceptance is not independent verification of mutable Apple/toolchain/account claims; recheck them during a future implementation effort.

Eight separate implementation tickets define the execution order and acceptance obligations:

1. [Watch targets, compatibility and development identity](implementation/01-watch-targets-and-compatibility.md)
2. [Shared resolved day and calendar presentation](implementation/02-shared-day-and-formatting.md)
3. [WidgetKit timeline provider and entry points](implementation/03-widgetkit-provider.md)
4. [Read-only Today and active-midnight refresh](implementation/04-watch-today.md)
5. [Four complication families and accessible presentation](implementation/05-complication-presentation.md)
6. [Isolated development boundary and failure harness](implementation/06-development-harness.md)
7. [Automated and native Watch readiness evidence](implementation/07-readiness-verification.md)
8. [Prepared signed build and physical-validation handoff](implementation/08-development-build-handoff.md)

The final acceptance gates remain distinct. The host baseline permits implementation start. Automated/native checks plus a development-signed artifact establish readiness for physical validation. Physical evidence establishes device validation. Final feature acceptance additionally requires an ADR-0001-compliant shared dataset. Public distribution is a separate follow-on effort.

Earlier continuation work started target/core changes outside the planning-only scope. Those changes remain in the working tree for review and are not accepted implementation evidence or completed tickets. This synthesis changes planning documents only.

## Deployment floor amendment

Commit `d8d5259` briefly set watchOS 26.6 for all Watch products; the user ratified **26.0** on 2026-10-04 and commit `3342b41` restored it, so the earlier watchOS 26.0 runtime results remain evidence at the current deployment floor.
