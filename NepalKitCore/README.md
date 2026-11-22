# NepalKitCore

Offline Bikram Sambat ↔ Gregorian conversion, Nepal Time, and Nepali date
formatting for Swift. It has no dependencies and makes no network requests.
NepalKitCore is the calendar engine of
[NepalKit](https://github.com/dibas-np/NepalKit), a macOS menu-bar and Apple
Watch app.

**0.x: the API may still change.** Until 1.0, a minor release can rename
things, so pin to a minor version. The [CHANGELOG](CHANGELOG.md) lists every
rename.

## Requirements

- Swift 6.2 tools or later (Xcode 26 or later)
- macOS 12, iOS 15, watchOS 9, tvOS 15 or visionOS 1 or later

Each release passes the full test suite on macOS, an iOS Simulator and a
watchOS Simulator, and builds for tvOS and visionOS, before it is tagged.

## Installation

In `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/dibas-np/NepalKitCore", .upToNextMinor(from: "0.2.0")),
],
targets: [
    .target(name: "YourTarget", dependencies: ["NepalKitCore"]),
]
```

In Xcode, choose **File › Add Package Dependencies…**, enter
`https://github.com/dibas-np/NepalKitCore`, and set the rule to **Up to Next
Minor Version**.

## Usage

```swift
import NepalKitCore

// Bikram Sambat to Gregorian, and back. Both are nil outside the supported
// range or for a date that does not exist.
let newYear = BikramSambatDate(year: 2083, month: 1, day: 1)
let gregorian = GregorianDate(newYear)             // 14 April 2026
let roundTrip = gregorian.flatMap { BikramSambatDate($0) }

// Today in Nepal Time (UTC+5:45), whatever the device's time zone, or in
// another zone.
let today = BikramSambatDate.today()
let todayHere = BikramSambatDate.today(timeZone: .current)

// Weekdays run 1 (Sunday) through 7 (Saturday).
gregorian?.weekday                                  // 3, a Tuesday

// Formatting, with Latin or Devanagari digits and Nepali or transliterated
// month names.
let nepali = DisplaySettings(digits: .devanagari, monthNames: .nepali)
newYear.formatted(nepali)                           // "१ बैशाख २०८३"
newYear.formatted(.init(digits: .latin, monthNames: .transliterated))
                                                    // "1 Baisakh 2083"
DigitScript.devanagari.format(2083)                 // "२०८३"
BikramSambatDate.monthName(6, style: .transliterated)  // "Ashoj"

// For a screen reader: Latin digits, which speech engines read reliably.
SpokenDate.bikramSambat(newYear, monthNames: .nepali)  // "1 बैशाख 2083"

// Festivals from the national Panchanga and public holidays from the Nepal
// Gazette, for the years listed in the tables.
FestivalCalendar.panchanga.festivals(on: newYear).map { $0.name(style: .transliterated) }
                                                    // ["Nepali New Year"]
PublicHolidayCalendar.gazette.isNationwideHoliday(newYear)  // true
```

To tell "outside the supported range" apart from invalid input, resolve the
day instead of converting it:

```swift
let day = try ResolvedDay(GregorianDate(year: 2030, month: 1, day: 1))
switch day.bikramSambat {
case .supported(let date): print(date)
case .beforeSupportedRange, .afterSupportedRange: print("outside the table")
}
// Throws DayResolutionError for a date that does not exist, such as 30 February.
```

## Supported dates

Conversions use `CalendarDataset.bundled` unless you pass a dataset. It is
currently `CalendarDataset.v2` (dataset version 2.0.1), which converts **1975
through 2084 Bikram Sambat**, 13 April 1918 through 12 April 2028 Gregorian.
Dates outside that range return nil. The table is never extrapolated. A future
release may point `bundled` at a newer table; pass `.v2` to pin this one.

**2084 BS is a provisional projection**, not an attested calendar:
`CalendarDataset.v2.isProvisional(2084)` is `true`. Festivals and public
holidays currently cover 2083 only.

Bikram Sambat month lengths are not computable from a formula, so conversion
reads a bundled table. Its historical base is
[askbuddie/bikram-sambat](https://github.com/askbuddie/bikram-sambat) at a
pinned commit, with 14 recorded corrections. NepalKit's
[SOURCES.md](https://github.com/dibas-np/NepalKit/blob/develop/SOURCES.md)
records every correction, the 2084 projection and the evidence limits. For
official use, consult the Panchanga Nirnayak Samiti's published Nepali Patro.

## Where development happens

This is a read-only mirror of `NepalKitCore/` in
[dibas-np/NepalKit](https://github.com/dibas-np/NepalKit), where issues and pull
requests go and where the source comments' SOURCES.md and `docs/adr/` live. Its
history is a reproducible `git subtree split`, and its tags are signed;
[Verifying a NepalKitCore release](https://github.com/dibas-np/NepalKit/blob/develop/docs/release-verification.md#verifying-a-nepalkitcore-release)
gives the commands.

## License

MIT; see [LICENSE](LICENSE). The month-length table's base is MIT, copyright
(c) 2023 Ask Buddie, with its notice in the resource bundle as
`AskBuddie-LICENSE.txt`. The NepalKit app is GPL-3.0-or-later.
