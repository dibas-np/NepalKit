# Changelog

NepalKitCore's releases. Versions follow semantic versioning. Until 1.0, a minor
release may change the public API. The NepalKit app versions separately; its
changelog is in the [NepalKit repository](https://github.com/dibas-np/NepalKit/blob/develop/CHANGELOG.md).

## 0.2.0 — Unreleased

The API is reviewed for use outside NepalKit. This release breaks every call
site; the table below maps each old name to its replacement.

- The date types are spelled out, and the free functions and global constants
  are now members of the types they act on.
- Every `in dataset:` parameter defaults to the new `CalendarDataset.bundled`,
  currently `v2`.
- `BikramSambatDate` is now `Comparable`, and both date types are `Codable`;
  `DigitScript`, `MonthNameStyle` and `DisplaySettings` are `Codable`.
- `DigitScript.formatTime` replaces `formatClock` and adds a 12-hour clock and
  an option to drop the seconds.
- Supports macOS 12, iOS 15, watchOS 9, tvOS 15 and visionOS 1, down from the
  26 releases.
- Removed, because only NepalKit used them: `MenuBarFormat`,
  `formatMenuBarTitle`, `formatClockTime`, `SpokenDate.menuBarDate`,
  `SpokenDate.gregorianAnnouncement`, `WatchDayDisplay` and its components,
  `watchDayDisplay`, `watchCalculationErrorDisplay`, `WatchDayCopy`,
  `ComplicationAccessibility` and `DisplaySettings.watch`.
- `DayResolutionError.calendarCalculationFailure` is removed; nothing could
  throw it.
- `TimeZone.nextMidnight(after:)` returns midnight, not 01:00, after a day
  whose clocks change at midnight, as in Havana or Santiago.

| 0.1 | 0.2 |
|---|---|
| `BSDay`, `GADay` | `BikramSambatDate`, `GregorianDate` |
| `bsToAD(bs, in: d)` | `GregorianDate(bs, in: d)` |
| `adToBS(ad, in: d)` | `BikramSambatDate(ad, in: d)` |
| `todayBS(now:timeZone:in:)` | `BikramSambatDate.today(now:timeZone:in:)` |
| `todayAD(now:timeZone:)` | `GregorianDate.today(now:timeZone:)` |
| `weekday(of: ad)` | `ad.weekday` |
| `weekday(of: bs, in: d)` | `bs.weekday(in: d)` |
| `nepalTimeZone` | `TimeZone.nepal` |
| `nextMidnight(after: date, in: zone)` | `zone.nextMidnight(after: date)` |
| `nextNPTMidnight(after: date)` | `TimeZone.nepal.nextMidnight(after: date)` |
| `noonUTC(for: ad)` | `ad.noonUTC` |
| `daysInGregorianMonth(year:month:)` | `GregorianDate.daysInMonth(year:month:)` |
| `formatBS(bs, settings: s)` | `bs.formatted(s)` |
| `formatBSShort(bs, settings: s)` | `bs.formatted(s, includesYear: false)` |
| `formatAD(ad, settings: s)` | `ad.formatted(digits: s.digits)` |
| `formatNumber(n, digits: d)` | `d.format(n)` |
| `formatClock(date, timeZone: z, digits: d)` | `d.formatTime(date, in: z)` |
| `monthName(month: m, style: s)` | `BikramSambatDate.monthName(m, style: s)` |
| `weekdayName(for: w, style: s)` | `BikramSambatDate.weekdayName(w, style: s)` |
| `shortWeekdayName(for: w, style: s)` | `BikramSambatDate.shortWeekdayName(w, style: s)` |
| `gregorianMonthName(m)` | `GregorianDate.monthName(m)` |
| `nepaliMonthNames`, `transliteratedMonthNames` | `BikramSambatDate.monthNames(style:)` |
| `nepaliWeekdayNames`, `englishWeekdayNames` | `BikramSambatDate.weekdayNames(style:)` |
| `gregorianMonthNames` | `GregorianDate.monthNames` |
| `resolvedDay(for: ad, in: d)` | `ResolvedDay(ad, in: d)` |
| `resolvedDay(now: date, in: d)` | `ResolvedDay(now: date, in: d)` |
| `SpokenDate.bs`, `SpokenDate.ad` | `SpokenDate.bikramSambat`, `SpokenDate.gregorian` |
| `dataset.anchorBS`, `dataset.anchorAD` | `dataset.anchorBikramSambat`, `dataset.anchorGregorian` |

## 0.1.0 — 2026-11-04

The first public release. It is the calendar engine that ships in NepalKit 1.7.0.

- Bikram Sambat ↔ Gregorian conversion for 1975–2084 BS (dataset 2.0.1), with
  2084 marked as a provisional projection.
- Today in Nepal Time or any time zone, and the next midnight in either.
- Formatting with Latin or Devanagari digits and Nepali or transliterated month
  and weekday names, plus spoken forms for VoiceOver and Siri.
- Festivals from the national Panchanga and public holidays from the Nepal
  Gazette, for 2083.
- Supports macOS 26, iOS 26 and watchOS 26.
- Licensed MIT. Before this release the code was part of NepalKit under
  GPL-3.0-or-later.
