<div align="center">
  <h1>NepalKit</h1>
  <p><em>🗓️ Today's Bikram Sambat date in your Mac's menu bar — with a live Nepal Time clock and a converter that cannot pick an invalid date.</em></p>
</div>

<p align="center">
  <a href="https://github.com/dibas-np/NepalKit/releases/latest"><img src="https://img.shields.io/github/v/tag/dibas-np/NepalKit?label=version&style=flat-square" alt="Version"></a>
  <a href="https://github.com/dibas-np/NepalKit/releases"><img src="https://img.shields.io/github/downloads/dibas-np/NepalKit/total?label=downloads&style=flat-square" alt="Downloads"></a>
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-GPL_v3-blue.svg?style=flat-square" alt="License"></a>
  <a href="#why-macos-26"><img src="https://img.shields.io/badge/macOS-26%2B-lightgrey.svg?style=flat-square" alt="macOS 26+"></a>
  <a href="https://github.com/dibas-np/NepalKit/actions/workflows/macos26-floor.yml"><img src="https://img.shields.io/github/actions/workflow/status/dibas-np/NepalKit/macos26-floor.yml?branch=main&label=macOS%2026%20floor&style=flat-square" alt="macOS 26 floor"></a>
</p>

<p align="center">
  <a href="#install">Install</a> ·
  <a href="#features">Features</a> ·
  <a href="#privacy">Privacy</a> ·
  <a href="#the-calendar-data">Calendar data</a> ·
  <a href="#how-it-updates">Updates</a> ·
  <a href="#known-issues">Known issues</a> ·
  <a href="CHANGELOG.md">Changelog</a> ·
  <a href="#license">License</a>
</p>

<p align="center">
  <img src="docs/img/popover.png" alt="The NepalKit popover: today's Bikram Sambat date as the hero, Nepal Time beside it, and the converter below" width="420" />
</p>

New here? [CONTRIBUTING.md](CONTRIBUTING.md) covers how to build and what the
project expects. [SUPPORT.md](SUPPORT.md) says where to ask, and
[GOVERNANCE.md](GOVERNANCE.md) says who decides.

## Features

- **Menu-bar date** — today's Bikram Sambat date, always visible, with no Dock
  icon and no Cmd-Tab presence. Launch at login is on by default, so the date is
  there from sign-in.
- **Today at a click** — the popover makes the full Bikram Sambat date the hero,
  with the Gregorian date and weekday beneath it.
- **Live clocks** — Nepal Time (UTC+5:45) regardless of your system time zone;
  the local time appears beside it only when your zone actually differs.
- **A converter that cannot be wrong** — day pickers are bounded by the real
  month lengths and the dataset's supported range, so an invalid date is
  structurally unpickable, and the direction toggle carries the converted date
  across so nothing is re-entered.
- **Yours to read** — Latin `0–9` or Devanagari `०–९` digits, Nepali or
  transliterated month names, applied to every date on every surface.
- **Updates you can trust** — signed, notarized, and updated in place via
  Sparkle against an EdDSA-verified feed; each update's alert carries release
  notes.

## Privacy

Everything the app *does* is offline. Conversion, the calendar dataset, today's
date, and settings are all local. No analytics, no telemetry, no account. The
one exception is the software update check, which is the only thing the app is
granted network access for.

## Install

NepalKit requires **macOS 26 or later** (see [Why macOS 26](#why-macos-26)) and
runs natively on both Apple Silicon and Intel Macs. It is not on the App Store —
it is distributed as a notarized DMG.

1. Download the DMG from the
   [Releases page](https://github.com/dibas-np/NepalKit/releases/latest), open
   it, and drag NepalKit into Applications. Developer ID signing plus
   notarization means Gatekeeper accepts it without a right-click workaround.
2. Look for the date in the menu bar.

Installed copies update in the app; each update's alert carries release notes.
One exception: installations of the original 1.0 cannot update in place (see
[Known issues](#known-issues)) — if you are on 1.0, install 1.1 from the DMG
once. Everything from 1.1 onward updates normally.

**Verify your download.** The feed is verified before it is published and can be
verified by anyone: it carries an Ed25519 signature over the archive bytes, and
the public key is in `NepalKit/Info.plist`. `scripts/verify-appcast.py` re-runs
the check with stock `openssl` and no private key:

```sh
python3 scripts/verify-appcast.py appcast.xml --enclosure NepalKit-1.1.zip
```

Exit 0 means the archive you downloaded is the archive that was signed.

## Using it

The popover puts **Today** — both calendars and the clocks — and **Convert** on
equal tabs, under a header that names the app and shows live Nepal Time. A
footer names where you are and carries the routes into **Settings**, **About**,
and **Quit**. Display settings and launch-at-login live in the Settings window
(Settings… in the popover, or Cmd-,).

Two independent display settings apply to every date on every surface:

| Setting | Options |
| --- | --- |
| Digits | Latin `0–9` or Devanagari `०–९` |
| Month names | Nepali or transliterated English |

Gregorian month names are always English — the month-name setting governs
Bikram Sambat month names and weekday names. The interface itself is English;
full UI localization is not yet supported.

NepalKit converts **1975–2084 BS** (1918-04-13 through 2028-04-12 Gregorian).
That is the range of the bundled, verified dataset, not a product limit: past it
the popover says so explicitly rather than showing a blank.

## The calendar data

Conversion is table-driven, not algorithmic. Bikram Sambat month lengths have no
closed-form rule, so the table is the product's correctness core.

- Dataset version `2.0.0`, covering **1975–2084 BS**
- Month lengths cross-checked year by year against three MIT-licensed community
  tables, with the 20 months where they disagree arbitrated individually and
  recorded; the most contested year was settled against the Kathmandu
  Metropolitan City calendar
- **2084 is projected, not published.** The official almanac exists through
  2083; 2084's determination is expected around January–February 2027. Three
  independent sources plus the Kathmandu Metropolitan City calendar agree on
  that year, so the values are well supported — but no authority has attested it
  yet. See [SOURCES.md](SOURCES.md)
- Every supported New Year boundary is a test in both conversion directions
- **Nothing is extrapolated.** Years without published data are excluded rather
  than projected (ADR-0001)
- **The range can narrow as well as extend.** Dataset 2.0.0 dropped 1970–1974 —
  the only years the corroborating table does not cover at all (ADR-0010)

<details>
<summary><strong>Licence, provenance, and regulatory status</strong></summary>

**The bundled table is not independently licensed, and this project does not
claim it is.** It derives from one base source across its entire range; that
source is a fork of an upstream carrying no licence file, and the fork later
added a licence of its own. The corroborating sources are a check, not the
origin of any value. A licence a copyright holder grants cannot extend to
material they do not hold rights in, so the GPL notice on the code says nothing
about the table. [SOURCES.md](SOURCES.md) states exactly what the data is.

- **Regulatory status is unresolved.** Whether distributing a Nepali almanac
  publicly requires approval from the Panchanga Nirnayak Samiti, and whether any
  fee applies, has not been established. This project publishes without claiming
  to have answered that question, and anyone relying on the calendar for
  official purposes should raise it with the Samiti.
- The bundled dataset is frozen per release. Changing the supported range means
  shipping a new dataset in a subsequent release — extending it once newer
  official Patro data is published, narrowing it if the shipped table can no
  longer be corroborated. It is never fetched at runtime (ADR-0002).
- Anyone can re-run the source comparison with
  `python3 scripts/verify-data-sources.py`.

</details>

## How it updates

NepalKit updates in place via
[Sparkle](https://sparkle-project.org), checked automatically after launch and
on demand from Settings → Software Update. The feed is live at
`https://dibas-np.github.io/NepalKit/appcast.xml`. If it cannot be reached, a
check reports the failure rather than claiming you are current.

- **Notarized twice, deliberately.** The app and the DMG are separate notary
  submissions, because Apple issues one ticket per submitted item and Sparkle
  copies the `.app` out of the enclosure — a DMG-only ticket would be discarded
  on every update, leaving Gatekeeper to reach Apple's servers at update time.
  The release runs `spctl` against the app itself for the same reason.
- **Release notes are a build step.** Each version's notes live at
  `scripts/release-notes/<version>.html`; the appcast step injects them into
  the feed item, `CHANGELOG.md` is regenerated from the same fragments, and a
  version without notes fails the release — the update alert renders them as
  HTML.
- **Signed updates.** The enclosure carries an EdDSA signature over its bytes,
  verifiable by anyone against the public key committed in `Info.plist`
  (see [Install](#install)). Appcast signing needs the private key, so
  it happens on the release machine and never in CI.

<details>
<summary><strong>Packaging a release</strong></summary>

```sh
xcrun notarytool store-credentials NepalKit-notary   # once
export TEAM_ID=XXXXXXXXXX                            # selects the certificate
./scripts/package-release.sh
```

`store-credentials` prompts for the Apple ID, app-specific password, and team
ID. The script then passes `--keychain-profile` and nothing else, so no secret
reaches the process list. Passing `--password` on the command line instead
would put the password in `argv`, which is world-readable through `ps` for as
long as each submission runs. A keychain profile is the only supported path, and the only one that keeps secrets out of `argv`. notarytool's environment-variable form (`APPLE_ID`, `APP_SPECIFIC_PASSWORD`) is deliberately not implemented — it would put the app-specific password in the process table for the length of each submission, and there is no CI release path that needs it. The one environment variable the script does require is `TEAM_ID`, which selects the signing certificate and is not a secret. The script reads its configuration from arguments and the environment only — it does **not** load a `.env` file.

The script archives with Developer ID Application signing and the hardened
runtime, exports, notarizes the app and the DMG as two submissions, staples
both, verifies the mounted app with `spctl`, and generates and verifies the
appcast.

The DMG window is designed rather than left to Finder: a background with an
arrow from the app to the Applications shortcut and a caption telling the user
what to do, laid out by Finder itself and generated from one description of the
layout in `scripts/make-dmg-artwork.swift`. Every other gate in the script
passes just as happily on a DMG whose window is Finder's default, so the window
is read back off the finished image and the release fails if it is not the
window that was designed. Building it needs two `hdiutil` calls that Apple has
deprecated and cannot be done without — the reasoning, the measurements, and
the one configuration where the composition is known to drift are in
[ADR-0013](docs/adr/0013-dmg-window-layout.md). The layout is scripted through
Finder, so the release machine's terminal needs Automation permission for it
once; the script says so by name if it does not have it.

`sign_update` blocks on a keychain access prompt; run the release in the
foreground where the prompt can be answered rather than in a batch that will
hang.

</details>

## Development

Requires Xcode 26.6 or later and a macOS 26+ machine to run. Xcode 26.6 is
proven, not assumed: the floor gate
([macos26-floor.yml](.github/workflows/macos26-floor.yml)) builds, tests, and
launches the app on a `macos-26` runner with that exact pin. The release
pipeline uses Xcode 27, and the Xcode project format stays at the level the
floor toolchain reads — decline Xcode 27's project-upgrade prompt.

```sh
git clone https://github.com/dibas-np/NepalKit.git
cd NepalKit
```

The app is an Xcode project; open `NepalKit.xcodeproj` and run the `NepalKit`
scheme. The conversion engine is a local Swift package, `NepalKitCore`, that
builds and tests on its own with no Xcode.

### Tests

```sh
# core: conversion, dataset, formatting          -> 52 tests, 14 suites
cd NepalKitCore && swift test

# app layer: models, settings persistence        -> 125 tests, 20 suites
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
scripts/          test runner, release packaging, appcast verification
docs/adr/         architecture decision records
```

The split is strict: anything expressible without a view belongs in
`NepalKitCore`, which is where the exhaustive date tests live. See
[CODING_STANDARDS.md](CODING_STANDARDS.md).

## Why macOS 26

macOS 26 (Tahoe) is the deployment floor and macOS 27 is the design target.
NepalKit uses modern Liquid Glass-era SwiftUI APIs directly, with no
compatibility shims and no degraded paths for older systems. Rendering
differences between the two are treated as OS behavior, not something to
compensate for (ADR-0003).

## Known issues

- **Installations of 1.0 cannot update in place, ever.** 1.0 was published
  without `SUEnableInstallerLauncherService`, which a sandboxed app needs for
  Sparkle's installer to launch at all. 1.1 fixes the updater, but that key is
  read from the *running* application, so a copy already on 1.0 has no way to
  reach it. **1.0 users must download and install 1.1 from the DMG once.** There
  is no fix from this side; the cohort is small and the debt is permanent.
  Everything from 1.1 onward updates normally.
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
- **The DMG window has only been seen on macOS 27.** It is laid out by Finder
  into an undocumented `.DS_Store`, and the release reads the window back off
  the finished image — so its geometry is gated, but "gated" is not "looked
  at". The composition has not been seen on the macOS 26 floor, and it is known
  to drift by about 16pt on a Mac whose Finder has the path bar turned off. See
  [ADR-0013](docs/adr/0013-dmg-window-layout.md) and the
  [fresh-Mac install procedure](docs/release-evidence/fresh-mac-install-procedure.md).
- **The supported range ends at 2084 BS.** Expected, and stated in the UI.

## License

**GNU General Public License v3.0 or later** — see [LICENSE](LICENSE), which
carries the verbatim text.

GPL-3.0 rather than a permissive licence is a deliberate choice about the
calendar data. `medic/bikram-sambat`, the base table, is Apache-2.0, and
Apache-2.0 is one-way compatible with GPLv3 — so GPL lets the table ship inside
the same grant as the code, where a permissive licence would have left the two
on separate and incompatible terms.

**The licence does not cover the bundled calendar table.** No licence a
copyright holder grants can extend to material they do not hold rights in. The
table derives from a fork of an upstream carrying no licence file, and this
project does not assert a licence over it. [SOURCES.md](SOURCES.md) states
exactly what the data is. A reader relying on this repository's licence for the
dataset is relying on something this repository does not assert.

## Acknowledgements

Calendar data cross-checked against several independent open converters and
confirmed against officially published Nepali calendars.
