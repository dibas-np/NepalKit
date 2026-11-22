// SPDX-License-Identifier: MIT
// Copyright (C) 2026 Dibas Sigdel
import Foundation

/// A civil day in the Gregorian calendar, independent of any time zone.
///
/// The components are stored unchecked; anything computed from an impossible
/// date such as February 30 returns nil.
public struct GregorianDate: Hashable, Sendable, Codable {
    public let year: Int
    public let month: Int
    public let day: Int

    public init(year: Int, month: Int, day: Int) {
        self.year = year
        self.month = month
        self.day = day
    }
}

extension GregorianDate: Comparable {
    public static func < (lhs: GregorianDate, rhs: GregorianDate) -> Bool {
        (lhs.year, lhs.month, lhs.day) < (rhs.year, rhs.month, rhs.day)
    }
}

extension GregorianDate {
    /// The Gregorian date of a Bikram Sambat date, or nil if the Bikram
    /// Sambat date does not exist or is outside the dataset's supported range.
    public init?(_ bikramSambat: BikramSambatDate, in dataset: CalendarDataset = .bundled) {
        guard let targetIndex = absoluteDayIndex(bikramSambat, in: dataset),
              let anchorIndex = absoluteDayIndex(dataset.anchorBikramSambat, in: dataset),
              let anchorDate = utcDate(from: dataset.anchorGregorian),
              let date = utcGregorian.date(byAdding: .day, value: targetIndex - anchorIndex, to: anchorDate),
              let converted = GregorianDate(utcDate: date)
        else { return nil }
        self = converted
    }

    /// The civil day at `now` in `timeZone`, Nepal Time by default.
    public static func today(now: Date = Date(), timeZone: TimeZone = .nepal) -> GregorianDate? {
        let components = ClockCalendars.gregorian(timeZone: timeZone).dateComponents([.year, .month, .day], from: now)
        guard let year = components.year, let month = components.month, let day = components.day else { return nil }
        return GregorianDate(year: year, month: month, day: day)
    }

    /// The weekday, 1 (Sunday) through 7 (Saturday), or nil if the date does
    /// not exist. Needs no dataset.
    public var weekday: Int? {
        utcDate(from: self).map { utcGregorian.component(.weekday, from: $0) }
    }

    /// The date `days` days later (earlier, for a negative value), or nil if
    /// this date does not exist.
    public func advanced(byDays days: Int) -> GregorianDate? {
        utcDate(from: self)
            .flatMap { utcGregorian.date(byAdding: .day, value: days, to: $0) }
            .flatMap(GregorianDate.init(utcDate:))
    }

    /// The date as an instant at noon UTC, or nil if it does not exist.
    ///
    /// Noon keeps the instant on the named day in zones from UTC−12 through
    /// UTC+11:59.
    public var noonUTC: Date? {
        utcDate(from: self)?.addingTimeInterval(12 * 60 * 60)
    }

    /// The number of days in a Gregorian month, or nil if `month` is outside
    /// 1–12.
    public static func daysInMonth(year: Int, month: Int) -> Int? {
        guard (1 ... 12).contains(month) else { return nil }
        var components = DateComponents()
        components.year = year
        components.month = month
        guard let date = utcGregorian.date(from: components),
              let range = utcGregorian.range(of: .day, in: .month, for: date)
        else { return nil }
        return range.count
    }

    init?(utcDate date: Date) {
        let components = utcGregorian.dateComponents([.year, .month, .day], from: date)
        guard let year = components.year, let month = components.month, let day = components.day else { return nil }
        self.init(year: year, month: month, day: day)
    }
}
