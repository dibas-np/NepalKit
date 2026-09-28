# NepalKit

A macOS menu-bar utility for Nepal-specific date and time. The menu bar shows
today's Bikram Sambat date; one click opens a popover with today's Bikram
Sambat and Gregorian dates, a live Nepal Time clock, and a BS ↔ Gregorian
converter.

Everything the app *does* is offline. Conversion, the calendar dataset, today's
date, and settings are all local, and nothing is fetched at runtime. No
analytics, no telemetry.

The one exception is the software update check, which is the only thing the app
is granted network access for. That check is not yet enabled: there is no
published feed, so nothing is contacted today. It will appear under
Settings → Software Update once a feed exists ([ADR-0012](docs/adr/0012-sparkle-version-pin.md)).

- **Requires macOS 26 or later** (see [Why macOS 26](#why-macos-26)).
- Not on the App Store — distributed as a notarized DMG from Releases.

## Install

Download the DMG from the project's Releases page, open it, and drag NepalKit
into Applications. The app is Developer ID signed and notarized, so Gatekeeper
accepts it without a right-click workaround.

NepalKit is a menu-bar-only app (`LSUIElement`): it has no Dock icon and does not
appear in Cmd-Tab. Look for the date in the menu bar. Launch at login is on by
default and can be toggled in the popover.

## Using it

The popover has three parts: **Today** (both calendars, Nepal Time, your local
time as a reference), a **converter** with a direction toggle and bounded
pickers, and your **display settings** plus **Quit**.

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

Requires Xcode 27 (or later) and a macOS 26+ machine to run.

```sh
git clone https://github.com/dibas-np/NepalKit.git
cd NepalKit
```

The app is an Xcode project; open `NepalKit.xcodeproj` and run the `NepalKit`
scheme. The conversion engine is a local Swift package, `NepalKitCore`, that
builds and tests on its own with no Xcode.

### Tests

```sh
# core: conversion, dataset, formatting          -> 44 tests, 11 suites
cd NepalKitCore && swift test

# app layer: models, settings persistence        -> 43 tests, 6 suites
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
- Month lengths cross-checked year by year against a second, MIT-licensed
  community table, with the 20 months where they disagree arbitrated
  individually and recorded
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
- **macOS 26 launch is unverified.** Every result to date is from macOS 27.
  Function and stability on the deployment floor is a release gate (ADR-0006),
  so a macOS 26 run is still outstanding.
- **Cross-machine installation is unverified.** Notarization acceptance,
  stapling, signature validation, and launching from the mounted DMG all pass
  locally, but no second Mac has confirmed a clean install.
- **The supported range ends at 2084 BS.** Expected, and stated in the UI.

## License

Not yet chosen. Add a `LICENSE` file before publishing publicly — without one,
the default is exclusive copyright and nobody else may legally use or
redistribute this.

## Acknowledgements

Calendar data cross-checked against several independent open converters and
confirmed against officially published Nepali calendars.
