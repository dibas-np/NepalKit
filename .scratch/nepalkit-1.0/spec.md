# NepalKit 1.0 Spec

Status: ready-for-agent

> This document is a **release delta**, not a replacement specification. The
> v1 spec at `.scratch/nepalkit-v1/spec.md` remains authoritative for the
> implemented product. Where the two disagree, this document wins, and the
> specific divergence is called out inline.
>
> The original v1 tickets, their resolutions, and ADRs 0001–0006 are history.
> Nothing here reopens them.

## Problem Statement

NepalKit works. The calendar engine is verified, the menu-bar utility is
built, the dataset is frozen, the release artifacts are signed and notarized,
and 86 tests pass. What it does not have is everything required to be
**installable by a stranger**: a public repository with a license, an update
mechanism, documented data provenance, a platform gate on its own deployment
floor, a settings surface, an about surface, and evidence that the distributed
artifact behaves on a machine that has never trusted the developer.

The gap is release infrastructure and evidence, not features.

## Solution

Close the distance between a working private application and a defensible
public 1.0 release, in twelve slices, without touching the implementation that
already satisfies the v1 spec.

## Baseline

```
10eff3e  feat: quit path, reproducible app tests, dataset boundary state
```

This is the correct baseline. It contains the release-critical completed work:
`CODING_STANDARDS.md`, `CONTEXT.md`, the tracked v1 `spec.md`,
`AppTermination.swift`, the reproducible app-layer test harness, the
range-boundary state, and the quit path.

Intentionally gitignored and local-only: `.env`, `AGENTS.md`, `docs/agents/`.
The tracked `NepalKit.xcodeproj/xcuserdata/` directory is a repository-hygiene
defect addressed in ticket 05.

### Complete and not re-worked

- 12/12 v1 tickets resolved
- Developer ID signing, Hardened Runtime, notarization, stapling, local
  Gatekeeper verification (`7a89f26d…`, 28 September 2026)
- Calendar dataset v1.0.0, 1970–2084 Bikram Sambat, three-source cross-check
- 44 `NepalKitCore` tests, 42 app-layer tests
- `SettingsStore`, Swift Testing, `SMAppService`, Icon Composer `.icon`
- Menu-bar rendering spike (1484 titles, 0 missing glyphs), ⌘Q
- Range-boundary state
- Tracked README, coding standards, v1 spec, app-test harness

## Product and architecture reference

Where an existing Mac utility is consulted as a product or UX reference, use
**only Mole for Mac**.

The upstream `tw93/Mole` repository is the free open-source `mo` CLI (Go,
GPL-3.0). Its own README separates them: *"This repo is the free open-source
CLI (mo). Prefer a native app? Mole for Mac is a separate download"* and
*"Mole for Mac is a separate proprietary app."* The repository's `swift` and
`swiftui` topic tags describe the Mac product, whose source is not in that
repository.

The upstream README also asks that a fork turned into another product take a
different name and credit Mole as the source. NepalKit is not a fork and copies
no source, so that condition is not triggered.

Not references: the `mo` CLI, its Go implementation, community MoleUI projects,
or any SwiftUI wrapper around the CLI.

NepalKit's architecture stays deliberately smaller:

```
SwiftUI macOS app
     ├── NepalKit app/UI
     └── NepalKitCore
           ├── conversion
           ├── formatting
           ├── calendar data
           └── pure tests
```

## Release contract

These are frozen before the first distributed build. Changing one afterwards is
a release decision, not a feature.

| Item | Value | Recorded in |
| --- | --- | --- |
| Bundle identifier | `com.dibas.NepalKit.NepalKit` (pending ownership, ticket 02) | — |
| App sandbox | Enabled | ADR-0008 |
| Network access | `com.apple.security.network.client` | ADR-0008 |
| Sparkle EdDSA keypair | Generated before first distributed build | — |
| Application version | `CFBundleShortVersionString` | ADR-0009 |
| Build number | `CFBundleVersion`, monotonically increasing | ADR-0009 |
| Calendar dataset version | `2.0.0` | — |
| Supported range | 1975–2084 Bikram Sambat | — |
| Ownership / copyright holder | **Unresolved — blocks public metadata** | — |

## User stories

Numbered continuously from the v1 spec (1–28), which remains in force.

29. As a user, I want NepalKit to check for and install its own updates, so
    that calendar-data extensions reach me without a manual download.
30. As a user, I want Settings in a proper native macOS window, so that
    preferences are where macOS users expect them.
31. As a user, I want an About surface showing the application version, the
    calendar dataset version, the supported range, the copyright holder, and
    the licence, so that I know what I am running and what it is based on.
32. As a user of assistive technology, I want the menu-bar date, the popover,
    the converter, Settings, and About to be navigable and correctly
    announced by VoiceOver, including when the digit script is Devanagari, so
    that the app is usable without sight.
33. As a user, I want the range-boundary state to be explained in words, naming
    the last supported Bikram Sambat year, so that a data limit is
    distinguishable from a bug.
34. As a user, I want to install a Developer ID signed, notarized disk image
    that Gatekeeper accepts without a workaround, so that installing NepalKit
    is uneventful.
35. As a contributor, I want the calendar data's provenance, licences, and
    cross-check methodology documented, so that I can reproduce the
    investigation and extend the supported range honestly.
36. As a maintainer, I want continuous integration proving the app builds and
    runs on its own deployment floor, so that the floor is a verified claim
    rather than an aspiration.
37. As a maintainer, I want the licence and copyright holder settled in
    writing, so that the MIT grant is granted by whoever actually holds the
    rights.

## Implementation decisions

**Sparkle is in 1.0, before the first distributed baseline.** Dataset extensions
are application releases, and the supported range ends 2028-04-12, so every
future extension is otherwise a manual redownload. The EdDSA private key is an
unrecoverable commitment: losing it means no installed copy ever updates again.
Introduce it early, back it up somewhere trusted, and never commit it. The
README's claim that the application makes no network calls stops being true the
moment Sparkle is integrated, so that correction ships in the same commit as the
integration rather than as later repository hygiene.

**The app is sandboxed with network-client access, and not with Sparkle's
Downloader XPC service.** A sandboxed Sparkle app may either take
`com.apple.security.network.client` or bundle the Downloader service. Upstream
documents the Downloader path's drawbacks directly: release notes fall back to a
deprecated `WebView`, external-content release notes break, and since 2.6 the
service is not sandboxed by default anyway. Take the entitlement instead. This
requires committing an entitlements file, which is why the sandbox decision
becomes a release-contract item (ADR-0008).

**Sparkle orders updates on `CFBundleVersion`, not on the human-facing version.**
Sparkle's documentation requires an incrementing, properly formatted
`CFBundleVersion` and uses it to decide what is newer; since 2.7 custom version
comparators are deprecated in favour of an increasing numeric build version kept
disjoint from `CFBundleShortVersionString`. Three version numbers are tracked
independently: the application version, the build number, and the calendar
dataset version (ADR-0009).

**The shipped calendar table is medic-derived for its entire range.** The base
table is `medic/bikram-sambat`; `askbuddie/bikram-sambat` corroborates 107 of
116 months; the 9 discrepancies were arbitrated against published Patro
material and a third table. `medic` is a fork of `alxndrsn/bikram-sambat.js`,
which carries no licence file, so the provenance chain is load-bearing. This is
stated plainly in `SOURCES.md` rather than presented as a clean licence
position.

**The supported range is cut to 1975–2084 Bikram Sambat, unconditionally.** The
1970–1974 years were the only ones resting on `medic` alone. The cut removes
those five single-source years; it does **not** make the remaining table
independently licensed, and no documentation may say that it does. Because the
supported range is part of the public conversion contract, this is a breaking
change and the dataset version becomes `2.0.0`. The lower Gregorian bound
follows from the dataset rather than being set independently, moving from
1913-04-13 to 1918-04-13.

**The project's Xcode file format is downgraded to object version 100.** The
project is currently object version 110, which is Xcode 27's format; Xcode 26
cannot open it, so a `macos-26` CI job fails before compiling a line. The
application source needs nothing: the highest API availability in use is macOS
15, there are no availability gates, both SwiftPM manifests load under Xcode 26,
and the Liquid Glass API family is macOS 26, not macOS 27. Xcode 27 continues to
open object version 100. The trade-off is that adopting a future Xcode 27-only
*project-file* feature requires raising it again and re-evaluating the gate.

**CI evidence from `macos-26` discharges the macOS 26 functional gate.** No
macOS 26 hardware is available; every result to date is from macOS 27. The gate
is behavioural — the project opens, builds, tests run, the app launches and
survives, the menu-bar item appears, no runaway launch loop occurs, ⌘Q exits
cleanly — and reproducible CI evidence is strictly better than a hand-run check
on borrowed hardware. macOS 27 remains the manual design-review platform, where
pixel judgement lives (ADR-0007).

**The range-boundary state is visually verified once, on a throwaway build, and
no date override ships.** The first unsupported Gregorian day is 2028-04-13,
nearly two years out, so nobody has seen this state render. Capture it by
overriding the injected clock on a scratch branch, then revert. Production
behaviour gains no launch arguments, no environment overrides, and no debug
hook. `DatasetBoundaryTests` remains the repeatable evidence; the screenshot is
one-time visual evidence that the UI matches the tests.

**VoiceOver readiness is a release-quality requirement, verified in this
release.** The application currently contains no accessibility API calls at
all. Mole for Mac's own README calls its Mac app VoiceOver-ready, which makes
the claim directly checkable. NepalKit has a specific reason to care that a
system utility does not: it renders Devanagari digits, and where VoiceOver's
spoken form of the rendered text is poor, add an explicit accessibility label
rather than changing the visual date.

**Settings architecture is settled by a short spike before it is built.** For a
menu-bar-only application, a native `Settings` scene has no application menu to
be reached from, and opening it requires activating a process whose activation
policy suppresses activation. Declare an empty `Settings {}` scene with a
popover button and find out before writing the real UI. If it cannot be reliably
reached, fall back to a controlled `WindowGroup` panel.

**The fresh-Mac gate precedes the first public release.** Everything verified
locally is verified on a machine that already trusts the developer. A fresh
machine is the only test that exercises what a downloader actually experiences,
and it is the only gate that catches the right-click-to-open failure class. The
first publicly downloadable artifact is one already proven to install cleanly
elsewhere.

**Ownership is a parallel track, not a numbered step.** The Apple Developer
account belongs to Finnove Technologies; that does not establish who holds
copyright in NepalKit or who may grant the MIT licence. The question is asked
immediately, and engineering proceeds in parallel, but no public metadata is
finalised before it is answered in writing.

## Testing decisions

- The 44 core and 42 app-layer tests remain the evidence for the existing
  product and are re-run, not rewritten.
- The app-layer SwiftPM harness at `scripts/apptests/` is the canonical app-layer
  runner; ADR-0005 records why. `xcodebuild test` hangs before connecting and
  remains a documented toolchain issue, not a reason to delete tests.
- The 1975 cut is made by changing the dataset boundary first, then running the
  full suite and letting failures reveal baked-in assumptions — roughly 13
  assertions across five test files encode the old lower bound. Expected values
  are not rewritten blind.
- CI runs the core suite, the app-layer suite, and a build on `macos-26` with an
  explicit `DEVELOPER_DIR`. Pull-request jobs run with
  `CODE_SIGNING_ALLOWED=NO` and require no signing secrets.
- A test asserts that build numbers increase, because nothing else catches a
  regression there until an update silently stops appearing.
- Accessibility is manually verified, not unit-tested: VoiceOver output is a
  platform rendering property. It is a release gate, not an automated one.
- The distributed artifact is tested, not only the Xcode Debug build.

## Out of scope

Month calendar view; public-holiday calendar UI; festivals; forex;
automatic calendar-data fetching; dataset extrapolation; Gregorian month-name
localisation; full Nepali user-interface localisation; help system; production
date override or debug hook; iOS companion; widgets; Shortcuts; analytics;
telemetry; additional Nepal utilities; the Mole CLI, its Go implementation,
community MoleUI projects, or any SwiftUI wrapper around the CLI; macOS 27-only
implementation requirements; cosmetic repository reorganisation; restoring
1970–1974 for this release.

## Tickets

Twelve slices. `01–08` and `10–12` are implementation or user-facing;
`09` is a release gate, not a product slice, and is labelled as such.

| #   | Slice | Blocked by |
| --- | --- | --- |
| 01 | Settings architecture spike | — |
| 02 | Project opens on the deployment-floor toolchain | — |
| 03 | Supported range is 1975–2084 Bikram Sambat | — |
| 04 | macOS 26 proves build, tests, and launch | 02 |
| 05 | Native Settings window | 01 |
| 06 | About surface | 03 |
| 07 | Check for Updates works end to end | sequenced after 01 |
| 08 | VoiceOver reads every surface correctly | 05, 06, 07 |
| 09 | Repository tells the truth *(release gate)* | 03, rights-holder resolution |
| 10 | Range-boundary state seen | 03 |
| 11 | Fresh Mac installs the candidate | 04, 05, 06, 07, 09 |
| 12 | A published update actually installs | 11 |

`07` is sequenced after `01` rather than blocked by it: both touch the
application's scene declarations, so doing the spike first avoids rework, but
Sparkle could be integrated first and adapted. The dependency is a preference,
not a technical constraint, and the ticket says so.

Three dependencies are external to the engineering tickets and are tracked
separately: the rights-holder conversation, the upstream provenance request, and
arranging second-Mac access.

## Release sequence

1. Settings architecture spike
2. Project opens on the deployment-floor toolchain
3. Supported range 1975–2084 Bikram Sambat
4. macOS 26 proves build, tests, and launch
5. Native Settings window
6. About surface
7. Check for Updates end to end
8. VoiceOver pass
9. Repository tells the truth
10. Range-boundary state seen
11. Fresh Mac installs the candidate
12. A published update actually installs
13. `1.0.0`

The frontier is `01`, `02`, and `03` — no blockers, so all three can start
immediately. The fresh-Mac gate precedes the first public release; nothing
publicly downloadable ships before it passes.

## Distinctions that define the remaining work

These are the separations the release turns on. Each was, or would have been,
easy to get wrong.

- implemented ≠ visually verified
- multi-source ≠ independent of `medic`
- notarized ≠ tested as a fresh download
- macOS 26-compatible source ≠ Xcode-26-readable project file
- Settings scene declared ≠ Settings activation solved
- private candidate ≠ public release
- source code MIT ≠ bundled calendar data independently licensed
