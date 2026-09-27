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

/// Days from the dataset anchor to the given BS date, or nil if outside the table.
func daysSinceAnchor(_ bs: BSDay, in dataset: CalendarDataset) -> Int? {
    guard bs.year >= dataset.anchorBS.year else { return nil }

    var days = 0
    // Whole years from the anchor year.
    for year in dataset.anchorBS.year ..< bs.year {
        guard let months = dataset.monthLengths(for: year) else { return nil }
        days += months.reduce(0, +)
    }
    // Whole months within the target year.
    guard let months = dataset.monthLengths(for: bs.year),
          bs.month >= 1, bs.month <= 12
    else { return nil }
    for month in 1 ..< bs.month {
        days += months[month - 1]
    }
    // Days within the target month, relative to the anchor day.
    guard bs.day >= 1, bs.day <= months[bs.month - 1] else { return nil }
    if bs.year == dataset.anchorBS.year, bs.month == dataset.anchorBS.month {
        return bs.day - dataset.anchorBS.day
    }
    days += bs.day - 1
    if bs.year == dataset.anchorBS.year {
        days -= dataset.anchorBS.day - 1
    }
    return days
}

/// Converts a Bikram Sambat date to Gregorian, or nil if outside the table.
public func bsToAD(_ bs: BSDay, in dataset: CalendarDataset) -> GADay? {
    guard let offset = daysSinceAnchor(bs, in: dataset) else { return nil }
    guard let anchorDate = utcDate(from: dataset.anchorAD),
          let date = utcGregorian.date(byAdding: .day, value: offset, to: anchorDate)
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
    guard offset >= 0 else { return nil }

    var remaining = offset
    var year = dataset.anchorBS.year
    var month = dataset.anchorBS.month
    var day = dataset.anchorBS.day
    while remaining > 0 {
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
    }
    return BSDay(year: year, month: month, day: day)
}

/// Weekday of a BS date as 1 (Sunday) through 7 (Saturday), or nil if outside the table.
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
