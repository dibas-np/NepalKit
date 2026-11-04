# NepalKitCore

Offline Bikram Sambat ↔ Gregorian conversion, Nepal Time, and Nepali date
formatting for Swift. NepalKitCore is the calendar engine of
[NepalKit](https://github.com/dibas-np/NepalKit), the macOS menu-bar and Apple
Watch app.

**0.x: the API is not stable yet.** The public API was written for the NepalKit
app and includes types only the app uses, such as `MenuBarFormat` and
`WatchDayDisplay`. Names may change in any minor release until 1.0, so pin to a
minor version.

## Requirements

- Swift 6.2 tools or later
- macOS 26, iOS 26 or watchOS 26 or later

Each release passes the full test suite on macOS, an iOS Simulator and a
watchOS Simulator before it is tagged.

## Installation

In `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/dibas-np/NepalKitCore", .upToNextMinor(from: "0.1.0")),
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

let dataset = CalendarDataset.v2

// Bikram Sambat to Gregorian, and back. Both return nil outside the
// supported range or for a date that does not exist.
let newYear = BSDay(year: 2083, month: 1, day: 1)
let gregorian = bsToAD(newYear, in: dataset)          // GADay(year: 2026, month: 4, day: 14)
let roundTrip = gregorian.flatMap { adToBS($0, in: dataset) }

// Today in Nepal Time (UTC+5:45), whatever the device's time zone.
let today = todayBS(now: .now, in: dataset)
let todayHere = todayBS(now: .now, timeZone: .current, in: dataset)

// Formatting, with Latin or Devanagari digits and Nepali or transliterated
// month names.
let nepali = DisplaySettings(digits: .devanagari, monthNames: .nepali)
formatBS(newYear, settings: nepali)                    // "१ बैशाख २०८३"
formatBS(newYear, settings: .init(digits: .latin, monthNames: .transliterated))
                                                       // "1 Baisakh 2083"

// Festivals from the national Panchanga and public holidays from the Nepal
// Gazette, for the years listed in the tables.
FestivalCalendar.panchanga.festivals(on: newYear).map { $0.name(style: .transliterated) }
                                                       // ["Nepali New Year"]
PublicHolidayCalendar.gazette.isNationwideHoliday(newYear)  // true
```

Months are 1-based (1 is Baisakh in Bikram Sambat, January in Gregorian), and
weekdays run 1 (Sunday) through 7 (Saturday).

## Supported dates

`CalendarDataset.v2` (dataset version 2.0.1) converts **1975 through 2084
Bikram Sambat**, April 13, 1918 through April 12, 2028 Gregorian. Dates outside
that range return nil. The table is never extrapolated.

**2084 BS is a provisional projection**, not an attested calendar:
`dataset.isProvisional(2084)` is `true`. Festivals and public holidays currently
cover 2083 only.

Bikram Sambat month lengths are not computable from a formula, so conversion
reads a bundled table. Its historical base is
[askbuddie/bikram-sambat](https://github.com/askbuddie/bikram-sambat) at a
pinned commit, with 14 recorded corrections. NepalKit's
[SOURCES.md](https://github.com/dibas-np/NepalKit/blob/develop/SOURCES.md)
records every correction, the 2084 projection and the evidence limits. For
official use, consult the Panchanga Nirnayak Samiti's published Nepali Patro.

## Where development happens

This repository is a read-only mirror of the `NepalKitCore/` directory in
[dibas-np/NepalKit](https://github.com/dibas-np/NepalKit). Open issues and pull
requests there. The source comments refer to that repository's SOURCES.md and
`docs/adr/`.

The mirror's history is `git subtree split --prefix=NepalKitCore` of the
NepalKit repository, so you can reproduce it yourself. Each release tag here is
signed, and a matching `core-v<version>` tag in NepalKit marks the source commit.
[Verifying a NepalKitCore release](https://github.com/dibas-np/NepalKit/blob/develop/docs/release-verification.md#verifying-a-nepalkitcore-release)
gives the commands.

## License

MIT. See [LICENSE](LICENSE). The month-length table's base is MIT-licensed,
copyright (c) 2023 Ask Buddie. Its complete notice ships in the package's
resource bundle as `AskBuddie-LICENSE.txt`.

The NepalKit app that uses this package is licensed separately, under
GPL-3.0-or-later.
