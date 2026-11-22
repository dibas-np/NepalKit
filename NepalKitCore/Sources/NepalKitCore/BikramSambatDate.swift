// SPDX-License-Identifier: MIT
// Copyright (C) 2026 Dibas Sigdel
import Foundation

/// A date in the Bikram Sambat calendar, with months 1 (Baisakh) through
/// 12 (Chaitra).
///
/// Whether the components name a real day depends on the dataset, so
/// validity is checked only where one is supplied.
public struct BikramSambatDate: Hashable, Sendable, Codable {
    public let year: Int
    public let month: Int
    public let day: Int

    public init(year: Int, month: Int, day: Int) {
        self.year = year
        self.month = month
        self.day = day
    }
}

extension BikramSambatDate: Comparable {
    public static func < (lhs: BikramSambatDate, rhs: BikramSambatDate) -> Bool {
        (lhs.year, lhs.month, lhs.day) < (rhs.year, rhs.month, rhs.day)
    }
}

extension BikramSambatDate {
    /// The Bikram Sambat date of a Gregorian date, or nil if the Gregorian
    /// date does not exist or is outside the dataset's supported range.
    public init?(_ gregorian: GregorianDate, in dataset: CalendarDataset = .bundled) {
        guard let anchorDate = utcDate(from: dataset.anchorGregorian),
              let targetDate = utcDate(from: gregorian),
              let anchorIndex = absoluteDayIndex(dataset.anchorBikramSambat, in: dataset),
              let offset = utcGregorian.dateComponents([.day], from: anchorDate, to: targetDate).day,
              let converted = bikramSambatDate(at: anchorIndex + offset, in: dataset)
        else { return nil }
        self = converted
    }

    /// Today's Bikram Sambat date in `timeZone`, or nil outside the supported
    /// range. Pass `.current` for the device's own day.
    public static func today(
        now: Date = Date(),
        timeZone: TimeZone = .nepal,
        in dataset: CalendarDataset = .bundled
    ) -> BikramSambatDate? {
        GregorianDate.today(now: now, timeZone: timeZone).flatMap { BikramSambatDate($0, in: dataset) }
    }

    /// The weekday, 1 (Sunday) through 7 (Saturday), or nil if the date does
    /// not exist or is outside the dataset's supported range.
    public func weekday(in dataset: CalendarDataset = .bundled) -> Int? {
        GregorianDate(self, in: dataset)?.weekday
    }
}
