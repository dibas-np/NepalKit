// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Dibas Sigdel
import Foundation

/// Nepal Time: the product's anchor for "today" (UTC+5:45).
public let nepalTimeZone: TimeZone = {
    guard let zone = TimeZone(secondsFromGMT: 20700) else {
        preconditionFailure("Foundation must support Nepal Time's fixed UTC+05:45 offset")
    }
    return zone
}()

/// Gregorian calendar in UTC: conversion is civil-day math, not instant math.
let utcGregorian: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = .gmt
    return calendar
}()

/// Gregorian calendar in Nepal Time, shared so the anchoring rule lives in
/// one place: "today" is the NPT civil day unconditionally (see the NPT
/// anchoring tests in TodayTests and the spec's Implementation Decisions).
let nptGregorian: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = nepalTimeZone
    return calendar
}()

/// A Gregorian date as a UTC civil day, or nil if the components do not name a
/// real day.
///
/// The single place a `GADay` becomes a `Date`, and therefore the single place
/// civil-day validity is checked. `Calendar` normalizes impossible input —
/// February 30 silently becomes March 1 — so anything that does not round-trip
/// exactly is rejected here rather than by each caller repeating the check.
/// Module-internal so the resolved-day resolvers validate input through this
/// same check instead of repeating it.
func utcDate(from ad: GADay) -> Date? {
    guard (1 ... 12).contains(ad.month) else { return nil }
    var components = DateComponents()
    components.year = ad.year
    components.month = ad.month
    components.day = ad.day
    guard let date = utcGregorian.date(from: components) else { return nil }
    let roundTripped = utcGregorian.dateComponents([.year, .month, .day], from: date)
    guard roundTripped.year == ad.year,
          roundTripped.month == ad.month,
          roundTripped.day == ad.day
    else { return nil }
    return date
}

/// The Gregorian civil day as an instant at noon UTC. Downstream date math
/// lands on the named day from UTC−12 inclusive through UTC+12 exclusive;
/// at UTC+12 and beyond the instant falls on the following local day, because
/// no instant can carry one civil day into all 26 hours of zones. Noon is
/// the reference that keeps both the Americas and Asia on the named day;
/// `NoonUTCTests` pins the window. Built on `utcDate`, so civil-day
/// validity is enforced here too.
public func noonUTC(for ad: GADay) -> Date? {
    utcDate(from: ad)?.addingTimeInterval(12 * 60 * 60)
}

/// Month lengths for a Bikram Sambat date after range and component
/// validation, or nil if the date is invalid or outside the table.
func validatedMonths(for bs: BSDay, in dataset: CalendarDataset) -> [Int]? {
    // A non-positive month length cannot appear in real data; guarding it
    // here keeps a corrupt row answering nil instead of building a reversed
    // range and trapping at conversion time.
    guard dataset.supportedRange.contains(bs.year),
          let months = dataset.monthLengths(for: bs.year),
          months.allSatisfy({ $0 >= 1 }),
          (1 ... 12).contains(bs.month),
          (1 ... months[bs.month - 1]).contains(bs.day)
    else { return nil }
    return months
}

/// Absolute day index of a Bikram Sambat date within the table (days since
/// the first day of the supported range), or nil if invalid or outside.
func absoluteDayIndex(_ bs: BSDay, in dataset: CalendarDataset) -> Int? {
    guard let yearStart = dataset.yearStartIndices[bs.year],
          let months = validatedMonths(for: bs, in: dataset)
    else { return nil }
    var index = yearStart
    for month in 1 ..< bs.month {
        index += months[month - 1]
    }
    return index + bs.day - 1
}

/// Converts a Bikram Sambat date to Gregorian, or nil if outside the table.
public func bsToAD(_ bs: BSDay, in dataset: CalendarDataset) -> GADay? {
    guard let targetIndex = absoluteDayIndex(bs, in: dataset),
          let anchorIndex = absoluteDayIndex(dataset.anchorBS, in: dataset),
          let anchorDate = utcDate(from: dataset.anchorAD),
          let date = utcGregorian.date(byAdding: .day, value: targetIndex - anchorIndex, to: anchorDate)
    else { return nil }
    let components = utcGregorian.dateComponents([.year, .month, .day], from: date)
    guard let year = components.year, let month = components.month, let day = components.day else { return nil }
    return GADay(year: year, month: month, day: day)
}

/// Bikram Sambat date at an absolute day index (inverse of absoluteDayIndex),
/// or nil if the index falls outside the table.
func bsDay(at index: Int, in dataset: CalendarDataset) -> BSDay? {
    guard index >= 0 else { return nil }
    for year in dataset.supportedRange {
        guard let yearStart = dataset.yearStartIndices[year],
              let months = dataset.monthLengths(for: year),
              months.allSatisfy({ $0 >= 1 })
        else { return nil }
        let yearLength = months.reduce(0, +)
        guard index >= yearStart + yearLength else {
            var remaining = index - yearStart
            for (offset, length) in months.enumerated() {
                guard remaining >= length else {
                    return BSDay(year: year, month: offset + 1, day: remaining + 1)
                }
                remaining -= length
            }
            return nil
        }
    }
    return nil
}

/// Converts a Gregorian date to Bikram Sambat, or nil if invalid or outside the table.
public func adToBS(_ ad: GADay, in dataset: CalendarDataset) -> BSDay? {
    // utcDate(from:) rejects dates that do not name a real civil day, so there
    // is no separate validation step here.
    guard let anchorDate = utcDate(from: dataset.anchorAD),
          let targetDate = utcDate(from: ad),
          let anchorIndex = absoluteDayIndex(dataset.anchorBS, in: dataset),
          let offset = utcGregorian.dateComponents([.day], from: anchorDate, to: targetDate).day
    else { return nil }
    return bsDay(at: anchorIndex + offset, in: dataset)
}

/// Weekday of a Bikram Sambat date as 1 (Sunday) through 7 (Saturday), or nil if outside the table.
public func weekday(of bs: BSDay, in dataset: CalendarDataset) -> Int? {
    guard let ad = bsToAD(bs, in: dataset) else { return nil }
    return weekday(of: ad)
}

/// Weekday of a Gregorian civil day as 1 (Sunday) through 7 (Saturday).
///
/// The weekday belongs to the civil day, not to either calendar, so it does not
/// need the dataset. Computing it through a Bikram Sambat conversion made it
/// vanish past the supported range, which is wrong: past that boundary the
/// Gregorian date and its weekday are still perfectly well defined and
/// answerable. This is the path the today view uses for exactly that reason.
public func weekday(of ad: GADay) -> Int? {
    guard let date = utcDate(from: ad) else { return nil }
    return utcGregorian.component(.weekday, from: date)
}

/// Number of days in a Gregorian month, or nil if the components do not name a
/// month.
///
/// Backs the converter's Gregorian day-picker bounds, so the picker ranges and
/// the conversion math share this one calendar and its UTC civil-day definition.
/// The month guard matters: `Calendar` silently normalizes month 0 into
/// December of the previous year, which would report a length for a month that
/// does not exist.
public func daysInGregorianMonth(year: Int, month: Int) -> Int? {
    guard (1 ... 12).contains(month) else { return nil }
    var components = DateComponents()
    components.year = year
    components.month = month
    guard let date = utcGregorian.date(from: components),
          let range = utcGregorian.range(of: .day, in: .month, for: date)
    else { return nil }
    return range.count
}

extension GADay {
    /// The civil day `days` after this one (before it, for negative values),
    /// or nil if the result does not name a real Gregorian day. Civil-day
    /// arithmetic, not instant arithmetic: the timeline horizon and any future
    /// day progression advance through here so the result is the named
    /// Gregorian day regardless of time zone.
    public func advanced(byDays days: Int) -> GADay? {
        guard let date = utcDate(from: self),
              let advanced = utcGregorian.date(byAdding: .day, value: days, to: date)
        else { return nil }
        let components = utcGregorian.dateComponents([.year, .month, .day], from: advanced)
        guard let year = components.year, let month = components.month, let day = components.day else { return nil }
        return GADay(year: year, month: month, day: day)
    }
}

/// Today's Bikram Sambat date, anchored to Nepal Time (UTC+5:45) unconditionally:
/// the Bikram Sambat date flips at NPT midnight regardless of the system time zone.
/// The clock is injected (`now`) so the anchoring is testable.
public func todayBS(now: Date, in dataset: CalendarDataset) -> BSDay? {
    guard let today = todayAD(now: now) else { return nil }
    return adToBS(today, in: dataset)
}

/// Today's Gregorian civil day in Nepal Time. The clock is injected (`now`)
/// so the anchoring is testable.
public func todayAD(now: Date) -> GADay? {
    let components = nptGregorian.dateComponents([.year, .month, .day], from: now)
    guard let year = components.year, let month = components.month, let day = components.day else { return nil }
    return GADay(year: year, month: month, day: day)
}

/// Next Nepal Time midnight after the given instant, for scheduling a
/// date-flip refresh. Returns nil only if calendar math fails.
public func nextNPTMidnight(after date: Date) -> Date? {
    let startOfToday = nptGregorian.startOfDay(for: date)
    return nptGregorian.date(byAdding: .day, value: 1, to: startOfToday)
}
