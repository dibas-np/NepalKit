# A general-purpose core API

Date: 2026-11-22
Status: accepted

## Context

NepalKitCore 0.1.0 published the API the app had grown
([ADR-0018](0018-publish-the-core-as-a-swift-package.md)). It carried app-only
types (`MenuBarFormat`, `WatchDayDisplay`, `WatchDayCopy`,
`ComplicationAccessibility`, `DisplaySettings.watch`, `nextNPTMidnight`), put
two dozen free functions and name arrays (`bsToAD`, `weekday(of:)`,
`formatNumber`, `nepalTimeZone`) into every importer's global scope, used
abbreviations other apps would have to learn (`BSDay`, `GADay`), and required
the 26 releases of macOS, iOS and watchOS, which excludes most apps.

## Decision

1. **App-only code leaves the published package.** Everything under
   `NepalKitCore/` ships to the mirror, so a second target there would still be
   published.
   - The Watch display meaning moves to a local package,
     `NepalKitWatchSupport/`. The Watch app, the complication extension and
     the Watch tests link it.
   - `MenuBarFormat` and `formatMenuBarTitle` move into the Mac app, the only
     user.
   - So does `SpokenDate.gregorianAnnouncement`.
   - Moved code is GPL-3.0-or-later like the rest of the app.
   - `nextNPTMidnight` is gone; `TimeZone.nepal.nextMidnight(after:)` replaces it.

2. **The types are spelled out and the functions become members.**

   | 0.1 | 0.2 |
   |---|---|
   | `BSDay`, `GADay` | `BikramSambatDate`, `GregorianDate` |
   | `bsToAD(bs, in:)`, `adToBS(ad, in:)` | `GregorianDate(bs, in:)`, `BikramSambatDate(ad, in:)` |
   | `todayBS`, `todayAD` | `BikramSambatDate.today(...)`, `GregorianDate.today(...)` |
   | `weekday(of: ad)`, `weekday(of: bs, in:)` | `ad.weekday`, `bs.weekday(in:)` |
   | `nepalTimeZone`, `nextMidnight(after:in:)` | `TimeZone.nepal`, `zone.nextMidnight(after:)` |
   | `formatBS`, `formatBSShort`, `formatAD` | `bs.formatted(_:includesYear:)`, `ad.formatted(digits:)` |
   | `formatNumber`, `formatClock` | `DigitScript.format(_:)`, `DigitScript.formatTime(...)` |
   | `monthName`, `weekdayName`, `gregorianMonthName`, the name arrays | statics on the date types |
   | `resolvedDay(for:in:)`, `resolvedDay(now:in:)` | `ResolvedDay(_:in:)`, `ResolvedDay(now:in:)` |
   | `SpokenDate.bs`, `SpokenDate.ad` | `SpokenDate.bikramSambat`, `SpokenDate.gregorian` |
   | `noonUTC(for:)`, `daysInGregorianMonth` | `ad.noonUTC`, `GregorianDate.daysInMonth` |

   Every `in dataset:` parameter defaults to `CalendarDataset.bundled`,
   currently `v2`. The app passes its dataset explicitly. The date types and
   the display settings are `Codable`, and both date types are `Comparable`.

3. **Lower floors: macOS 12, iOS 15, watchOS 9, tvOS 15 and visionOS 1.**
   These are the lowest the current Xcode builds for; it raises anything lower
   without a warning. `release-core.sh` still runs the suite on the newest
   macOS, iOS and watchOS. It builds for tvOS and visionOS without testing,
   since there are no simulator runtimes for them on the release machine.

4. **Still 0.x.** This ships as 0.2.0, a breaking minor release. 1.0 waits
   until outside use has tested these names.

## Consequences

- `CODING_STANDARDS.md`'s "BS"/"AD" allowance now covers app identifiers only.
- The Watch exception in `CODING_STANDARDS.md` names `NepalKitWatchSupport`
  rather than the core as the shared home for the Watch's copy and labels.
- `check-all.sh` and the macOS 26 floor workflow run the Watch support suite
  as their own gate.
- The core's tests no longer cover the menu-bar title or the Watch display.
  The app suite and the Watch support suite do.
- An app on 0.1 has to rename its calls; the table above is the migration
  guide, and the core's CHANGELOG repeats it.

## Considered options

- **`@_spi(NepalKit)` for the app-only code.** Rejected: it would still ship in
  the mirror under MIT, and the SPI would leak into other apps' autocompletion.
- **Keep `BSDay`/`GADay`.** Rejected by the maintainer: they read as internal
  shorthand to anyone outside this repository.
- **Keep the 26 floors.** Rejected: nothing in the core needs them, and they
  exclude most apps.
