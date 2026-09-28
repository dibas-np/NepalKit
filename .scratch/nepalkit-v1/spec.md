# NepalKit v1 Spec

Status: ready-for-agent

## Problem Statement

People who live by the Bikram Sambat calendar — in Nepal, in the diaspora, or working with Nepali dates — have no quick, native way to see today's Bikram Sambat date on their Mac. Checking the date means opening a browser, breaking focus, and trusting whatever converter loads first. Nepal Time and BS ↔ Gregorian conversion are equally scattered across ad-supported websites, with nothing designed for glanceable, offline, always-present access.

## Solution

NepalKit is a macOS menu-bar utility that is always one click away. The menu bar shows today's Bikram Sambat date; clicking it opens a popover with today's Bikram Sambat and Gregorian dates, live Nepal Time alongside system-local time, and a BS ↔ AD converter — all offline, all native, all following Apple design guidelines.

## User Stories

1. As a Mac user who follows the Bikram Sambat calendar, I want today's BS date visible in the menu bar at all times, so that I can glance at it without opening anything.
2. As a user, I want to click the menu-bar date and see a popover with full date details, so that I get more context without leaving my current app.
3. As a user, I want the popover to show today's date in both Bikram Sambat and Gregorian, so that I can relate the two systems instantly.
4. As a user, I want to see the current time in Nepal Time in the popover, so that I know the time in Nepal at a glance.
5. As a user outside Nepal, I want to see my system-local time next to Nepal Time, so that I can compare the two.
6. As a user, I want the BS date shown to flip at midnight Nepal Time regardless of my system time zone, so that the displayed date is always correct for Nepal.
7. As a user, I want a BS → AD converter, so that I can translate any supported Bikram Sambat date into the Gregorian calendar.
8. As a user, I want an AD → BS converter, so that I can translate any convertible Gregorian date into Bikram Sambat.
9. As a user, I want to switch converter direction with a single toggle, so that I don't re-enter dates to convert the other way.
10. As a user, I want to enter converter dates through bounded day/month/year pickers, so that I can never select an invalid date.
11. As a user, I want converter pickers constrained to the dataset's supported range, so that I can only ask for conversions the app can answer.
12. As a converter user, I want to see the weekday of the converted date, so that I get the complete answer in one place.
13. As a user who reads Devanagari, I want a digit-script setting with Devanagari ०–९ digits, so that dates render in the script I prefer.
14. As a user who reads Latin digits, I want a digit-script setting with Latin 0–9 digits, so that dates render in the script I prefer.
15. As a Nepali-reading user, I want month names in Nepali, so that the whole date reads naturally.
16. As an English-reading user, I want transliterated English month names, so that I can read BS dates without knowing Devanagari.
17. As a user, I want the digit-script and month-name settings to apply uniformly across the menu bar, popover, and converter — governing Bikram Sambat month names and weekday names — while Gregorian month names stay English, so that every date is presented in one deliberate script rather than arbitrarily.
18. As a user, I want my display settings to persist across relaunches, so that I set them once.
19. As a user, I want display settings accessible inside the popover, so that I can change them where I see their effect.
20. As a user, I want NepalKit to launch at login, so that today's date is in the menu bar from the moment I sign in.
21. As a user, I want to toggle launch-at-login, so that I control whether the app starts automatically.
22. As a menu-bar-utility user, I want no Dock icon or Cmd-Tab presence, so that NepalKit stays out of the way like a proper menu-bar citizen.
23. As a user with unreliable internet, I want all dates, conversion, and time display to work fully offline, so that the app never depends on a network.
24. As a user, I want conversion results I can trust, so that the bundled data is transcribed from the officially approved annual Nepali Patro and cross-checked.
25. As a user on macOS 26 or 27, I want a native Liquid Glass interface following Apple design guidelines with SF Symbols iconography, so that the app feels at home on my system.
26. As a user installing outside the App Store, I want a Gatekeeper-clean notarized DMG, so that installation is smooth and trusted.
27. As a menu-bar-utility user, I want an obvious Quit item in the popover carrying the standard ⌘Q shortcut, and I expect the shortcut to actually work rather than merely be drawn, so that I can exit NepalKit normally instead of forcing it to quit.
28. As a user on a date past the bundled data, I want the popover to state plainly that the Bikram Sambat date is unavailable and name the last supported year, while still showing the Gregorian date and Nepal Time, so that the end of the data is never a silent blank or a mystery.

## Implementation Decisions

- The conversion engine (calendar table, BS ↔ AD conversion, formatting logic) lives in a separate local Swift package; the app target holds only menu-bar UI, settings, and app-specific behavior.
- Conversion is pure logic over a bundled static reference table: BS month lengths are declared per year with no closed-form algorithm, so the table is transcribed year-by-year from the officially approved annual Nepali Patro, with New Year and month-start boundary dates cross-checked against two independent converters (per ADR-0001).
- The table contains only verified calendar data with no extrapolated or projected years; its supported BS range is explicitly defined by the dataset itself and expands only when new official Patro data becomes available (per ADR-0001). No extrapolation is a hard requirement; a clear range boundary state is a v1 UX requirement — past the last supported year the popover states that the Bikram Sambat date is unavailable and names the last supported year, beside the Gregorian date, its weekday, and the clocks that remain answerable. The weekday is a property of the civil day and does not depend on the dataset, so it survives the boundary. The menu bar stays compact: it shows a short marker rather than a bare dash, and gains no warning badge. The current boundary (2084 BS / 2028-04-12 Gregorian) belongs to the bundled dataset, not to the product: the release process extends it by shipping a new dataset.
- The dataset carries an explicit calendar-data version and declared supported BS range; v1 data is frozen and ships inside the app, with future app releases able to bundle expanded datasets and no automatic data fetching in v1 (per ADR-0002).
- "Today" is anchored to Nepal Time (UTC+5:45) unconditionally; the BS date changes at NPT midnight regardless of system time zone, and system-local time is shown only as secondary reference info.
- The converter uses a direction toggle with bounded day/month/year pickers clamped to the dataset's supported range; invalid dates are prevented structurally by the picker logic, and output shows the converted date plus the weekday.
- Display is governed by two independent persisted settings — digit script (Devanagari vs Latin) and month-name language (Nepali vs transliterated English) — applied uniformly across the menu bar, popover, converter output, and weekday names, using the canonical transliteration table agreed for all twelve months. The month-name setting governs Bikram Sambat month names and weekday names only: Gregorian month names are always English, on every surface, and no Nepali Gregorian month-name table is invented for v1. A Bikram Sambat date in Nepali above its English Gregorian counterpart is intentional, not mixed display.
- The weekday is calculated for the current date and displayed once, using the selected weekday language, on the combined Gregorian date line. Bikram Sambat and Gregorian are representations of the same calendar day, so computing it once and showing it on the Gregorian line is correct; it is a property of the date, not of either calendar, and is never described as a Bikram Sambat weekday. In Devanagari + Nepali this yields `२७ असोज २०८३` above `२७ September २०२६ · आइत`.
- The menu bar shows today's BS date in short form honoring both display settings; clicking opens a popover with today details (both calendars, NPT and local time) plus sections for the converter, the display settings, and a Quit item. The Quit item carries ⌘Q, delivered through the application's termination command group (`CommandGroup(replacing: .appTermination)`) rather than a button-local `keyboardShortcut`, so it works whenever the app is frontmost instead of only while the popover holds focus — an LSUIElement app is frequently not frontmost, so a popover-only shortcut is not an exit path. The shortcut must be verified to function, not merely displayed. No About window, version line, or Help surface in v1.
- The app is menu-bar only with no Dock presence, and launch-at-login (default on) is implemented through the modern system login-item service.
- Minimum deployment target is macOS 26 with design led by macOS 27; the app uses modern Liquid Glass-era SwiftUI menu-bar APIs directly with no compatibility shims, follows Apple design guidelines throughout, and treats OS-level material rendering differences between macOS 26 and 27 as expected behavior (per ADR-0003). Verification is two-tier: macOS 26 is a functional and stability release gate — it launches, does not enter the known runaway launch loop, shows the menu-bar item, opens the popover, navigates, and neither crashes nor pegs the CPU — while macOS 27 is the primary design and rendering target. Pixel-for-pixel parity on 26 is not required. Not currently having a macOS 26 environment is a release-blocking evidence gap, not an accepted unknown (per ADR-0006).
- All UI iconography uses SF Symbols with per-surface rendering modes chosen for contrast against translucent materials; the app icon is authored as a layered icon package for correct Liquid Glass variants; the menu-bar extra is date text only (per ADR-0004).
- Distribution is a notarized DMG via public code-hosting releases; Developer ID signing and notarization are set up early as release infrastructure. Bundle identifier, sandbox configuration, and the update story are frozen before the first distributed build; a later change to any of them is a release decision, not a v1 feature. Automatic updates are not part of v1.
- Cross-machine installation and Gatekeeper verification remain unverified: notarization acceptance, stapling, signature validation, and launching the app from the mounted DMG have all passed locally, but no second Mac has confirmed installation. This is a known limitation, distinct from the macOS 26 launch gate.
- Before finalizing the menu-bar layout, a rendering spike validates Devanagari BS date presentation (font rendering, truncation, spacing, both numeral settings) in the status-bar presentation on supported macOS versions.
- Before committing to the final supported range, the actual officially published BS range available at dataset-creation time is established; nothing is extrapolated.

## Testing Decisions

- A good test asserts externally observable behavior through a seam, never implementation internals: given a date and settings, the conversion or formatted string is correct.
- The primary seam is the core package boundary — pure conversion, NPT-anchored "today" with an injectable clock, and formatting for both digit scripts and both month-name languages. The full boundary/transition/round-trip/min-max/invalid-date matrix runs through this single seam.
- The versioned dataset is tested as a fixture: declared version and supported range, no gaps or overlaps, year/month structural consistency, valid month-length constraints, and agreement with the conversion engine's assumptions.
- The core test matrix explicitly covers every supported BS New Year boundary, every BS month transition, variable-length BS months, BS year transitions, AD leap years, both conversion round-trip directions, minimum/maximum supported dates, and invalid dates.
- Settings persistence (defaults, Devanagari ↔ Latin survival across relaunch, Nepali ↔ English survival across relaunch, correct decoding of stored values) is automated within the app layer as the one cheap, non-visual failure mode.
- A fresh checkout has one documented command that runs the complete app-layer suite, so the app-layer tests are never merely present but unreachable. The harness at `scripts/apptests/` symlinks the real `NepalKit/` and `NepalKitTests/` directories rather than copying them, so it always compiles current app sources. `xcodebuild test` currently hangs before connecting in the development environment (reproduces with an empty test; suspected LSUIElement host plus Xcode beta, which Apple labels a possible bug), so the app-layer suite runs through the harness; establishing CI on a known-good Xcode is the follow-up that supersedes it (per ADR-0005).
- Native visual UI — popover layout, Liquid Glass rendering, Devanagari rendering spike, SF Symbol presentation — is verified manually, not unit-tested: automate deterministic logic and persistence, manually verify native visual UI.
- There is no prior test art in the codebase to follow; this is a greenfield repo and these decisions establish its testing conventions.

## Out of Scope

- Month calendar view and Nepali public holidays (queued for a later release).
- Foreign exchange rates, festivals, tithi, and horoscope content (explicitly deferred; they require network/data pipelines v1 must not carry).
- Nepal Sambat dates.
- Automatic calendar-data fetching or updates outside app releases.
- App Store distribution; macOS versions below 26.
- A Nepali or otherwise localized user interface. NepalKit v1 uses an English interface; the display-language setting applies to Bikram Sambat month names and weekday names only, so English chrome ("Today", "Converter", "Year", "Month", "Day", "Launch at login", "Settings", "Quit NepalKit") around localized date content is intentional. No `.strings` infrastructure is introduced before the UI has stabilized.
- Full-window mode, widgets, notifications, or any surface beyond the menu-bar extra and its popover.

## Further Notes

- This spec synthesizes the locked Q1–Q22 requirements deliberation. The supersession to remember is Q21 over Q7: macOS 26+ is the deployment floor, replacing the earlier macOS 14+ position.
- Domain language follows the project glossary (Bikram Sambat, Gregorian, Nepal Time, Nepali Patro); data-source and platform constraints are recorded in the project's architecture decision records.
- Pre-implementation follow-ups (rendering spike, test matrix, notarization pipeline) are tracked alongside this spec in the local issue tracker and do not expand v1 scope.
