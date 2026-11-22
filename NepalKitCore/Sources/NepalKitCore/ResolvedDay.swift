// SPDX-License-Identifier: MIT
// Copyright (C) 2026 Dibas Sigdel
import Foundation

/// One civil day with both calendar identities resolved, for code that must
/// tell "outside the supported range" from "something is wrong".
///
/// The conversion initializers return nil for both. A `ResolvedDay` always
/// carries the Gregorian date and its weekday, which stay answerable outside
/// the dataset, and reports the Bikram Sambat side as supported or as an
/// expected boundary. Invalid input and a broken dataset throw
/// `DayResolutionError` instead, so a boundary is never mistaken for an error
/// or the reverse.
public struct ResolvedDay: Sendable, Hashable {
    /// The Bikram Sambat side of the day. A range boundary is an expected
    /// result, not an error.
    public enum BikramSambatStatus: Sendable, Hashable {
        /// The day is inside the dataset's supported range.
        case supported(BikramSambatDate)
        /// The day is before the dataset's first supported day.
        case beforeSupportedRange
        /// The day is after the dataset's last supported day.
        case afterSupportedRange
    }

    /// The Gregorian date. Always present.
    public let gregorian: GregorianDate

    /// The weekday, 1 (Sunday) through 7 (Saturday), shared by both calendars.
    public let weekday: Int

    public let bikramSambat: BikramSambatStatus

    /// Resolves a Gregorian date.
    ///
    /// The boundary is decided from the dataset's exact Gregorian bounds,
    /// never from a failed conversion, which would conflate "outside the
    /// table" with "the table is broken".
    ///
    /// - Throws: `DayResolutionError`.
    public init(_ date: GregorianDate, in dataset: CalendarDataset = .bundled) throws {
        guard utcDate(from: date) != nil else {
            throw DayResolutionError.invalidCivilDay(date)
        }
        guard let weekday = date.weekday else {
            throw DayResolutionError.calendarCalculationFailure(date)
        }
        // Each bound is derived only when needed, so a day before the range
        // still resolves when the end of the table is what is broken.
        guard let start = dataset.gregorianStart else {
            throw DayResolutionError.datasetAssumptionFailure(date)
        }
        self.gregorian = date
        self.weekday = weekday
        if date < start {
            self.bikramSambat = .beforeSupportedRange
            return
        }
        guard let end = dataset.gregorianEnd else {
            throw DayResolutionError.datasetAssumptionFailure(date)
        }
        if date > end {
            self.bikramSambat = .afterSupportedRange
        } else if let converted = BikramSambatDate(date, in: dataset) {
            self.bikramSambat = .supported(converted)
        } else {
            throw DayResolutionError.datasetAssumptionFailure(date)
        }
    }

    /// Resolves the civil day at `now` in `timeZone`, Nepal Time by default.
    ///
    /// - Throws: `DayResolutionError`.
    public init(now: Date, timeZone: TimeZone = .nepal, in dataset: CalendarDataset = .bundled) throws {
        guard let date = GregorianDate.today(now: now, timeZone: timeZone) else {
            throw DayResolutionError.unreadableInstant(now)
        }
        try self.init(date, in: dataset)
    }
}

/// Why a day could not be resolved. Every case is invalid input or a defect;
/// a date outside the supported range is a `ResolvedDay` boundary instead.
public enum DayResolutionError: Error, Sendable, Hashable {
    /// The components do not name a real Gregorian day (February 30, month
    /// 13, day 0).
    case invalidCivilDay(GregorianDate)

    /// The dataset failed to answer a day it claims to cover, or its bounds
    /// could not be derived.
    case datasetAssumptionFailure(GregorianDate)

    /// Calendar arithmetic failed for a valid day. Unreachable while
    /// Foundation behaves.
    case calendarCalculationFailure(GregorianDate)

    /// The civil day could not be read from the instant. Unreachable while
    /// Foundation behaves.
    case unreadableInstant(Date)

    /// The valid Gregorian date the failure happened on, if there was one.
    /// Nil for invalid input, so an error display never shows a date that
    /// does not exist.
    public var resolvedGregorianDay: GregorianDate? {
        switch self {
        case .datasetAssumptionFailure(let day), .calendarCalculationFailure(let day):
            day
        case .invalidCivilDay, .unreadableInstant:
            nil
        }
    }
}
