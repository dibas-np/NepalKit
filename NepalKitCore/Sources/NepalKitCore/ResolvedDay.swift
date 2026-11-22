// SPDX-License-Identifier: MIT
// Copyright (C) 2026 Dibas Sigdel
import Foundation

/// One civil day with both calendar identities resolved.
///
/// Unlike the conversion initializers, which return nil for any failure, this
/// tells "outside the supported range" apart from invalid input or a broken
/// dataset, which throw `DayResolutionError`.
public struct ResolvedDay: Sendable, Hashable {
    /// The Bikram Sambat side of the day.
    public enum BikramSambatStatus: Sendable, Hashable {
        /// The day is inside the dataset's supported range.
        case supported(BikramSambatDate)
        /// The day is before the dataset's first supported day.
        case beforeSupportedRange
        /// The day is after the dataset's last supported day.
        case afterSupportedRange
    }

    /// The Gregorian date.
    public let gregorian: GregorianDate

    /// The weekday, 1 (Sunday) through 7 (Saturday), shared by both calendars.
    public let weekday: Int

    public let bikramSambat: BikramSambatStatus

    /// Resolves a Gregorian date.
    ///
    /// - Throws: `DayResolutionError`.
    public init(_ date: GregorianDate, in dataset: CalendarDataset = .bundled) throws {
        guard let weekday = date.weekday else {
            throw DayResolutionError.invalidCivilDay(date)
        }
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

/// Why a day could not be resolved: invalid input or a defect.
public enum DayResolutionError: Error, Sendable, Hashable {
    /// The components do not name a real Gregorian day.
    case invalidCivilDay(GregorianDate)

    /// The dataset failed to answer a day it claims to cover.
    case datasetAssumptionFailure(GregorianDate)

    /// The civil day could not be read from the instant.
    case unreadableInstant(Date)

    /// The valid Gregorian date the failure happened on; nil for invalid input.
    public var resolvedGregorianDay: GregorianDate? {
        switch self {
        case .datasetAssumptionFailure(let day):
            day
        case .invalidCivilDay, .unreadableInstant:
            nil
        }
    }
}
