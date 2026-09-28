import Foundation

/// Nepal Time: the product's anchor for "today" (UTC+5:45).
public let nepalTimeZone = TimeZone(secondsFromGMT: 20700)!

/// Gregorian calendar in UTC: conversion is civil-day math, not instant math.
let utcGregorian: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0)!
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

/// A Gregorian date as a UTC civil day.
private func utcDate(from ad: GADay) -> Date? {
    var components = DateComponents()
    components.year = ad.year
    components.month = ad.month
    components.day = ad.day
    return utcGregorian.date(from: components)
}

/// Month lengths for a Bikram Sambat date after range and component
/// validation, or nil if the date is invalid or outside the table.
func validatedMonths(for bs: BSDay, in dataset: CalendarDataset) -> [Int]? {
    guard dataset.supportedRange.contains(bs.year),
          let months = dataset.monthLengths(for: bs.year),
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
              let months = dataset.monthLengths(for: year)
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
    guard let anchorDate = utcDate(from: dataset.anchorAD),
          let targetDate = utcDate(from: ad),
          let anchorIndex = absoluteDayIndex(dataset.anchorBS, in: dataset)
    else { return nil }
    // Calendar normalizes invalid components (e.g. Feb 30 becomes Mar 1),
    // so reject dates that don't round-trip exactly.
    let roundTripped = utcGregorian.dateComponents([.year, .month, .day], from: targetDate)
    guard roundTripped.year == ad.year, roundTripped.month == ad.month, roundTripped.day == ad.day else { return nil }
    let offset = utcGregorian.dateComponents([.day], from: anchorDate, to: targetDate).day ?? 0
    return bsDay(at: anchorIndex + offset, in: dataset)
}

/// Weekday of a Bikram Sambat date as 1 (Sunday) through 7 (Saturday), or nil if outside the table.
public func weekday(of bs: BSDay, in dataset: CalendarDataset) -> Int? {
    guard let ad = bsToAD(bs, in: dataset),
          let date = utcDate(from: ad)
    else { return nil }
    return utcGregorian.component(.weekday, from: date)
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
