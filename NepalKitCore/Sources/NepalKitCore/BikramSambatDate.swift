// SPDX-License-Identifier: MIT
// Copyright (C) 2026 Dibas Sigdel
import Foundation

/// A date in the Bikram Sambat calendar: a year, a month from 1 (Baisakh)
/// through 12 (Chaitra), and a day of that month.
///
/// The value holds whatever components it was given; whether they name a real
/// day depends on the dataset, so validity is checked where a dataset is
/// supplied. Conversion returns nil for a date that does not exist.
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
        // utcDate(from:) rejects dates that do not name a real civil day, so
        // there is no separate validation step here.
        guard let anchorDate = utcDate(from: dataset.anchorGregorian),
              let targetDate = utcDate(from: gregorian),
              let anchorIndex = absoluteDayIndex(dataset.anchorBikramSambat, in: dataset),
              let offset = utcGregorian.dateComponents([.day], from: anchorDate, to: targetDate).day,
              let converted = bikramSambatDate(at: anchorIndex + offset, in: dataset)
        else { return nil }
        self = converted
    }

    /// Today's Bikram Sambat date: the civil day at `now` in `timeZone`,
    /// converted. Nil outside the dataset's supported range.
    ///
    /// Defaults to Nepal Time, so the date changes at midnight in Nepal
    /// whatever the device's zone. Pass `.current` for the device's own day.
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
