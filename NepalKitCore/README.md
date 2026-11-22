# NepalKitCore

NepalKitCore converts dates between Bikram Sambat and Gregorian, gives today's
date in Nepal Time, and formats Nepali dates in Swift. It works offline and has
no dependencies. It is the calendar engine of
[NepalKit](https://github.com/dibas-np/NepalKit), a macOS menu-bar and Apple
Watch app.

**The API can still change.** Until 1.0, a minor release can rename things, so
pin to a minor version. The [CHANGELOG](CHANGELOG.md) lists every rename.

## Requirements

- Swift 6.2 tools or later, which ships with Xcode 26
- macOS 12, iOS 15, watchOS 9, tvOS 15, or visionOS 1, or a later version of each

Before each release is published, the full test suite passes on macOS, an iOS
Simulator, and a watchOS Simulator, and the package builds for tvOS and
visionOS.

## Installation

To add the package in `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/dibas-np/NepalKitCore", .upToNextMinor(from: "0.2.0")),
],
targets: [
    .target(name: "YourTarget", dependencies: ["NepalKitCore"]),
]
```

To add it in Xcode, choose **File** > **Add Package Dependencies**, enter
`https://github.com/dibas-np/NepalKitCore`, and set **Dependency Rule** to
**Up to Next Minor Version**.

## Usage

```swift
import NepalKitCore

// Bikram Sambat to Gregorian, and back. Each conversion returns nil outside
// the supported range or for a date that does not exist.
let newYear = BikramSambatDate(year: 2083, month: 1, day: 1)
let gregorian = GregorianDate(newYear)             // 14 April 2026
let roundTrip = gregorian.flatMap { BikramSambatDate($0) }

// Today in Nepal Time (UTC+5:45), whatever the device's time zone, or in
// another zone.
let today = BikramSambatDate.today()
let todayHere = BikramSambatDate.today(timeZone: .current)

// Weekdays run from 1 (Sunday) through 7 (Saturday).
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
// Gazette, for the years in the tables.
FestivalCalendar.panchanga.festivals(on: newYear).map { $0.name(style: .transliterated) }
                                                    // ["Nepali New Year"]
PublicHolidayCalendar.gazette.isNationwideHoliday(newYear)  // true
```

A conversion returns nil both for a date outside the supported range and for
a date that does not exist. To tell the two apart, resolve the day instead:

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
currently `CalendarDataset.v2`, dataset version 2.0.1, which converts **1975
through 2084 Bikram Sambat**. In Gregorian dates, that is 13 April 1918 through
12 April 2028. Dates outside that range return nil, because the package never
extrapolates the table. A future release can point `bundled` at a newer table.
To keep this one, pass `.v2`.

**2084 BS is a provisional projection**, not an attested calendar.
`CalendarDataset.v2.isProvisional(2084)` returns `true`. Festivals and public
holidays cover 2083 only.

No formula gives Bikram Sambat month lengths, so conversion reads a bundled
table. Its historical base is
[askbuddie/bikram-sambat](https://github.com/askbuddie/bikram-sambat) at a
pinned commit, with 14 month lengths corrected. NepalKit's
[SOURCES.md](https://github.com/dibas-np/NepalKit/blob/develop/SOURCES.md)
records each correction, the 2084 projection, and the limits of the evidence.
For official use, check the Nepali Patro that the Panchanga Nirnayak Samiti
publishes.

## Where development happens

This repository is a read-only mirror of `NepalKitCore/` in
[dibas-np/NepalKit](https://github.com/dibas-np/NepalKit). Open issues and pull
requests there. The mirror's history is a reproducible `git subtree split`, and
its tags are signed. To check them, see
[Check a NepalKitCore release](https://github.com/dibas-np/NepalKit/blob/develop/docs/release-verification.md#check-a-nepalkitcore-release).

## License

NepalKitCore is MIT-licensed. See [LICENSE](LICENSE). The base of the
month-length table is MIT-licensed, copyright (c) 2023 Ask Buddie. Its notice
ships in the resource bundle as `AskBuddie-LICENSE.txt`. The NepalKit app is
GPL-3.0-or-later.
