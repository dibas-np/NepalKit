import Foundation

private let utcGregorian: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "UTC")!
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
    guard dataset.supportedRange.contains(bs.year) else { return nil }
    var index = 0
    for year in dataset.supportedRange.lowerBound ..< bs.year {
        guard let months = dataset.monthLengths(for: year) else { return nil }
        index += months.reduce(0, +)
    }
    guard let months = validatedMonths(for: bs, in: dataset) else { return nil }
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

/// Converts a Gregorian date to Bikram Sambat, or nil if outside the table.
public func adToBS(_ ad: GADay, in dataset: CalendarDataset) -> BSDay? {
    guard let anchorDate = utcDate(from: dataset.anchorAD),
          let targetDate = utcDate(from: ad)
    else { return nil }
    let offset = utcGregorian.dateComponents([.day], from: anchorDate, to: targetDate).day ?? 0

    var year = dataset.anchorBS.year
    var month = dataset.anchorBS.month
    var day = dataset.anchorBS.day
    var remaining = offset
    while remaining != 0 {
        if remaining > 0 {
            guard let months = dataset.monthLengths(for: year) else { return nil }
            day += 1
            if day > months[month - 1] {
                day = 1
                month += 1
                if month > 12 {
                    month = 1
                    year += 1
                }
            }
            remaining -= 1
        } else {
            day -= 1
            if day < 1 {
                month -= 1
                if month < 1 {
                    month = 12
                    year -= 1
                }
                guard let months = dataset.monthLengths(for: year) else { return nil }
                day = months[month - 1]
            }
            remaining += 1
        }
    }
    let landed = BSDay(year: year, month: month, day: day)
    guard validatedMonths(for: landed, in: dataset) != nil else { return nil }
    return landed
}

/// Weekday of a Bikram Sambat date as 1 (Sunday) through 7 (Saturday), or nil if outside the table.
public func weekday(of bs: BSDay, in dataset: CalendarDataset) -> Int? {
    guard let ad = bsToAD(bs, in: dataset),
          let date = utcDate(from: ad)
    else { return nil }
    return utcGregorian.component(.weekday, from: date)
}

/// Today's Bikram Sambat date, anchored to Nepal Time (UTC+5:45) unconditionally:
/// the BS date flips at NPT midnight regardless of the system time zone.
/// The clock is injected (`now`) so the anchoring is testable.
public func todayBS(now: Date, in dataset: CalendarDataset) -> BSDay? {
    var nptCalendar = Calendar(identifier: .gregorian)
    nptCalendar.timeZone = TimeZone(identifier: "Asia/Kathmandu")!
    let components = nptCalendar.dateComponents([.year, .month, .day], from: now)
    guard let year = components.year, let month = components.month, let day = components.day else { return nil }
    return adToBS(GADay(year: year, month: month, day: day), in: dataset)
}
