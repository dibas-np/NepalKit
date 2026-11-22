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
    /// when the date changes. Nil only if calendar math fails.
    ///
    /// Uses the start of the next day rather than adding 24 hours, so zones
    /// with daylight saving time get their real midnight on 23- and 25-hour
    /// days.
    public func nextMidnight(after date: Date) -> Date? {
        let calendar = ClockCalendars.gregorian(timeZone: self)
        return calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: date))
    }
}

/// The Gregorian calendar in UTC: conversion is civil-day math, not instant math.
let utcGregorian: Calendar = {
    // Not `TimeZone.gmt`, which needs macOS 13.
    guard let utc = TimeZone(secondsFromGMT: 0) else {
        preconditionFailure("Foundation must support a UTC time zone")
    }
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = utc
    return calendar
}()

/// A Gregorian date as a UTC civil day, or nil if the components do not name a
/// real day.
///
/// The single place a `GregorianDate` becomes a `Date`, and therefore the
/// single place civil-day validity is checked. `Calendar` normalizes
/// impossible input (February 30 silently becomes March 1), so anything that
/// does not round-trip exactly is rejected here.
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

/// Month lengths for a Bikram Sambat date after range and component
/// validation, or nil if the date is invalid or outside the table.
func validatedMonths(for date: BikramSambatDate, in dataset: CalendarDataset) -> [Int]? {
    // A non-positive month length cannot appear in real data; guarding it
    // here keeps a corrupt row answering nil instead of building a reversed
    // range and trapping at conversion time.
    guard dataset.supportedRange.contains(date.year),
          let months = dataset.monthLengths(for: date.year),
          months.allSatisfy({ $0 >= 1 }),
          (1 ... 12).contains(date.month),
          (1 ... months[date.month - 1]).contains(date.day)
    else { return nil }
    return months
}

/// Absolute day index of a Bikram Sambat date within the table (days since
/// the first day of the supported range), or nil if invalid or outside.
func absoluteDayIndex(_ date: BikramSambatDate, in dataset: CalendarDataset) -> Int? {
    guard let yearStart = dataset.yearStartIndices[date.year],
          let months = validatedMonths(for: date, in: dataset)
    else { return nil }
    return yearStart + months.prefix(date.month - 1).reduce(0, +) + date.day - 1
}

/// Bikram Sambat date at an absolute day index (inverse of absoluteDayIndex),
/// or nil if the index falls outside the table.
func bikramSambatDate(at index: Int, in dataset: CalendarDataset) -> BikramSambatDate? {
    guard index >= 0 else { return nil }
    for year in dataset.supportedRange {
        guard let yearStart = dataset.yearStartIndices[year],
              let months = dataset.monthLengths(for: year),
              months.allSatisfy({ $0 >= 1 })
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
