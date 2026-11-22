// SPDX-License-Identifier: MIT
// Copyright (C) 2026 Dibas Sigdel
import Foundation

extension TimeZone {
    /// Nepal Time, UTC+5:45. Nepal has no daylight saving time.
    public static let nepal: TimeZone = {
        guard let zone = TimeZone(secondsFromGMT: 20700) else {
            preconditionFailure("Foundation must support Nepal Time's fixed UTC+05:45 offset")
        }
        return zone
    }()

    /// The first midnight in this zone after `date`, for scheduling a refresh
    /// when the date changes. Correct on 23- and 25-hour DST days.
    public func nextMidnight(after date: Date) -> Date? {
        let calendar = ClockCalendars.gregorian(timeZone: self)
        return calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: date)).map(calendar.startOfDay(for:))
    }
}

let utcGregorian: Calendar = {
    // Not `TimeZone.gmt`, which needs macOS 13.
    guard let utc = TimeZone(secondsFromGMT: 0) else {
        preconditionFailure("Foundation must support a UTC time zone")
    }
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = utc
    return calendar
}()

/// `Calendar` normalizes February 30 to March 1, so anything that
/// does not round-trip is rejected.
func utcDate(from date: GregorianDate) -> Date? {
    guard (1 ... 12).contains(date.month) else { return nil }
    var components = DateComponents()
    components.year = date.year
    components.month = date.month
    components.day = date.day
    guard let instant = utcGregorian.date(from: components),
          GregorianDate(utcDate: instant) == date
    else { return nil }
    return instant
}

func validatedMonths(for date: BikramSambatDate, in dataset: CalendarDataset) -> [Int]? {
    guard dataset.validYears.contains(date.year),
          let months = dataset.monthLengths(for: date.year),
          (1 ... 12).contains(date.month),
          (1 ... months[date.month - 1]).contains(date.day)
    else { return nil }
    return months
}

func absoluteDayIndex(_ date: BikramSambatDate, in dataset: CalendarDataset) -> Int? {
    guard let yearStart = dataset.yearStartIndices[date.year],
          let months = validatedMonths(for: date, in: dataset)
    else { return nil }
    return yearStart + months.prefix(date.month - 1).reduce(0, +) + date.day - 1
}

func bikramSambatDate(at index: Int, in dataset: CalendarDataset) -> BikramSambatDate? {
    guard index >= 0 else { return nil }
    for year in dataset.supportedRange {
        guard dataset.validYears.contains(year),
              let yearStart = dataset.yearStartIndices[year],
              let months = dataset.monthLengths(for: year)
        else { return nil }
        guard index >= yearStart + months.reduce(0, +) else {
            var remaining = index - yearStart
            for (offset, length) in months.enumerated() {
                guard remaining >= length else {
                    return BikramSambatDate(year: year, month: offset + 1, day: remaining + 1)
                }
                remaining -= length
            }
            return nil
        }
    }
    return nil
}
