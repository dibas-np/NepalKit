# NepalKit

A macOS menu-bar utility for Nepal-specific date and time. The menu bar shows
today's Bikram Sambat date; one click opens a popover with today's Bikram
Sambat and Gregorian dates, a live Nepal Time clock, and a BS ↔ Gregorian
converter.

Everything the app *does* is offline. Conversion, the calendar dataset, today's
date, and settings are all local. No analytics, no telemetry.

The one exception is the software update check, which is the only thing the app
is granted network access for. It runs against the feed URL pinned in the
binary ([ADR-0012](docs/adr/0012-sparkle-version-pin.md)): automatically after
launch and on demand from Settings → Software Update. The feed is not live yet,
so until it is published a check honestly reports "could not check" rather
than claiming you are current.

- **Requires macOS 26 or later** (see [Why macOS 26](#why-macos-26)).
- Not on the App Store — distributed as a notarized DMG from Releases.

[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)](LICENSE)
[![macOS 26+](https://img.shields.io/badge/macOS-26%2B-lightgrey.svg)](#why-macos-26)

New here? [CONTRIBUTING.md](CONTRIBUTING.md) covers how to build and what the
project expects. [SUPPORT.md](SUPPORT.md) says where to ask, and
[GOVERNANCE.md](GOVERNANCE.md) says who decides.

## Install

Download the DMG from the project's Releases page, open it, and drag NepalKit
into Applications. The app is Developer ID signed and notarized, so Gatekeeper
accepts it without a right-click workaround.

NepalKit is a menu-bar-only app (`LSUIElement`): it has no Dock icon and does not
appear in Cmd-Tab. Look for the date in the menu bar. Launch at login is on by
default and can be toggled in Settings → Startup.

## Using it

The popover has two parts: **Today** (both calendars, Nepal Time, your local
time as a reference) and a **converter** with a direction toggle and bounded
pickers, plus routes into **Settings**, **About**, and **Quit**. Display
settings and launch-at-login live in the Settings window (Settings… in the
popover, or Cmd-,).

Two independent display settings apply to every date on every surface:

| Setting | Options |
| --- | --- |
| Digits | Latin `0–9` or Devanagari `०–९` |
| Month names | Nepali or transliterated English |

Gregorian month names are always English — the month-name setting governs
Bikram Sambat month names and weekday names. The interface itself is English in
v1; full UI localization is not yet supported.

NepalKit converts **1975–2084 BS** (1918-04-13 through 2028-04-12 Gregorian).
That is the range of the bundled, verified dataset, not a product limit: past it
the popover says so explicitly rather than showing a blank.

## Development

Requires Xcode 26.6 or later and a macOS 26+ machine to run. Xcode 26.6 is
proven, not assumed: the floor gate
([macos26-floor.yml](.github/workflows/macos26-floor.yml)) builds, tests, and
launches the app on a `macos-26` runner with that exact pin. The release
pipeline uses Xcode 27.

```sh
git clone https://github.com/dibas-np/NepalKit.git
cd NepalKit
```

The app is an Xcode project; open `NepalKit.xcodeproj` and run the `NepalKit`
scheme. The conversion engine is a local Swift package, `NepalKitCore`, that
builds and tests on its own with no Xcode.

### Tests

```sh
# core: conversion, dataset, formatting          -> 47 tests, 13 suites
cd NepalKitCore && swift test

# app layer: models, settings persistence        -> 96 tests, 15 suites
./scripts/run-app-tests.sh
```

`xcodebuild test` builds NepalKit clean but the test runner hangs before
connecting in some environments. It reproduces with an empty test, so it is the
menu-bar-only app host interacting with the Xcode beta rather than anything in
this code. `scripts/run-app-tests.sh` is the supported runner in the meantime:
it is a SwiftPM package at `scripts/apptests/` that **symlinks** the real
`NepalKit/` and `NepalKitTests/` directories, so it compiles the actual app
sources and cannot drift from them. See
[ADR-0005](docs/adr/0005-app-layer-test-execution.md).

### Architecture

```
NepalKitCore/     pure logic: calendar dataset, BS ↔ Gregorian conversion, formatting
  Sources/        imports Foundation only — no AppKit, no SwiftUI
  Tests/
NepalKit/         app target: menu-bar UI, settings, app behavior
  NepalKitApp.swift    the MenuBarExtra scene
  PopoverView.swift    today + converter + settings + quit
  *Model.swift         @MainActor @Observable models
  SettingsStore.swift  UserDefaults persistence
NepalKitTests/    app-layer tests
scripts/          test runner, release packaging, menu-bar rendering spike
docs/adr/         architecture decision records
```

The split is strict: anything expressible without a view belongs in
`NepalKitCore`, which is where the exhaustive date tests live. See
[CODING_STANDARDS.md](CODING_STANDARDS.md).

## The calendar data

Conversion is table-driven, not algorithmic. Bikram Sambat month lengths have no
closed-form rule, so the table is the product's correctness core.

- Dataset version `2.0.0`, covering **1975–2084 BS**
- Month lengths cross-checked year by year against three MIT-licensed community
  tables, with the 20 months where they disagree arbitrated individually and
  recorded; the most contested year was settled against the Kathmandu
  Metropolitan City calendar
- **2084 is projected, not published.** The official almanac exists through 2083;
  2084's determination is expected around January–February 2027. Three
  independent sources plus the Kathmandu Metropolitan City calendar agree on that
  year, so the values are well supported — but no authority has attested it yet.
  See [SOURCES.md](SOURCES.md)
- Every supported New Year boundary is a test in both conversion directions
- **Nothing is extrapolated.** Years without published data are excluded rather
  than projected (ADR-0001)
- **The range can narrow as well as extend.** Dataset 2.0.0 dropped 1970–1974 —
  the only years the corroborating table does not cover at all (ADR-0010)

**The bundled table is not independently licensed, and this project does not
claim it is.** It derives from one base source across its entire range; that
source is a fork of an upstream carrying no licence file, and the fork later
added a licence of its own. The corroborating source is a check, not the origin
of any value.

**[SOURCES.md](SOURCES.md)** records every source, pinned to a commit, with its
licence, its role, the arbitration of each disputed month, and the two arguments
that sound protective and are not. Anyone can re-run the comparison with
`python3 scripts/verify-data-sources.py`.

The bundled dataset is frozen per release. Changing the supported range means
shipping a new dataset in a subsequent release — extending it once newer official
Patro data is published, narrowing it if the shipped table can no longer be
corroborated. It is never fetched at runtime (ADR-0002).

## Releases

```sh
APPLE_ID=... APP_SPECIFIC_PASSWORD=... TEAM_ID=... ./scripts/package-release.sh
```

Archives with Developer ID Application signing and the hardened runtime, exports,
builds a UDZO DMG, submits to the notary service, staples the ticket, and
verifies the mounted app with `spctl`. Credentials are read from the environment only —
`APPLE_ID`, `APP_SPECIFIC_PASSWORD`, and `TEAM_ID` — and the script exits if any
is missing. It does **not** read a `.env` file; an earlier version of this
document claimed it did, and the script has never done so. Both the environment
and any local `.env` are gitignored, so keeping a local `.env` is a convenient
habit, but exporting the three variables is what the script actually reads.

## Why macOS 26

macOS 26 (Tahoe) is the deployment floor and macOS 27 is the design target.
NepalKit uses modern Liquid Glass-era SwiftUI APIs directly, with no compatibility
shims and no degraded paths for older systems. Rendering differences between the
two are treated as OS behavior, not something to compensate for (ADR-0003).

## Known issues

- **`xcodebuild test` hangs** before connecting on some toolchains. Use
  `./scripts/run-app-tests.sh`; see [ADR-0005](docs/adr/0005-app-layer-test-execution.md).
- **`Cmd-Q` has not been functionally verified.** The shortcut is registered on
  the app's termination command group and the app builds and launches, but
  keystroke injection is refused in the development environment, so nobody has
  yet confirmed it terminates the app when the app is frontmost with the popover
  closed. That is the case the `CommandGroup` choice exists to serve, so it is
  worth confirming rather than assuming.
- **The dataset-boundary notice has never been seen.** The boundary is
  2028-04-13, so the popover's out-of-range layout is asserted by tests but has
  not been eyeballed.
- **Cross-machine installation is unverified.** Notarization acceptance,
  stapling, signature validation, and launching from the mounted DMG all pass
  locally, and the floor gate builds and launches on a real `macos-26` runner,
  but no second Mac has confirmed a clean *install* of the shipped DMG — the
  CI runner builds from source, which is a different path.
- **The supported range ends at 2084 BS.** Expected, and stated in the UI.

## License

**GNU General Public License v3.0 or later** — see [LICENSE](LICENSE), which
carries the verbatim text.

GPL-3.0 rather than a permissive licence is a deliberate choice about the
calendar data. `medic/bikram-sambat`, the base table, is Apache-2.0, and
Apache-2.0 is one-way compatible with GPLv3 — so GPL lets the table ship inside
the same grant as the code, where a permissive licence would have left the two
on separate and incompatible terms. That compatibility is a reason, not a cure:
see below.

**The licence does not cover the bundled calendar table.** No licence a
copyright holder grants can extend to material they do not hold rights in. The
table derives from a fork of an upstream carrying no licence file, and this
project does not assert a licence over it. `SOURCES.md` states exactly what the
data is. A reader relying on this repository's licence for the dataset is relying
on something this repository does not assert.

## Acknowledgements

Calendar data cross-checked against several independent open converters and
confirmed against officially published Nepali calendars.
