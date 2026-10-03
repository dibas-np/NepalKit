// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Dibas Sigdel
import Foundation

/// One Nepal Time civil day with both calendar identities resolved.
///
/// The value is the shared currency of every Watch surface: the timeline
/// builder resolves a horizon of these, the Today model renders one, and the
/// complication views compose what their entry carries. It always carries a
/// Gregorian civil day and that day's single weekday — Gregorian progression
/// continues outside the supported range — and its Bikram Sambat identity is
/// either supported or an explicit expected boundary, per the Range boundary
/// state glossary entry. What it never carries is a failure: invalid input,
/// broken dataset assumptions, and unexpected calculations throw, so an
/// expected boundary can never masquerade as an error or the reverse.
public struct ResolvedDay: Sendable, Hashable {
    /// The Bikram Sambat identity of the day. A range boundary is an expected
    /// domain result, not an error.
    public enum BikramSambatStatus: Sendable, Hashable {
        /// The day is inside the dataset's supported range.
        case supported(BSDay)
        /// The day is before the dataset's first supported Gregorian day.
        case beforeSupportedRange
        /// The day is after the dataset's last supported Gregorian day.
        case afterSupportedRange
    }

    /// The Gregorian civil day this resolution belongs to. Always present.
    public let gregorian: GADay

    /// The day's single weekday, 1 (Sunday) through 7 (Saturday). A weekday
    /// belongs to the resolved day, so both calendar representations share it
    /// and no surface ever shows it twice.
    public let weekday: Int

    public let bikramSambat: BikramSambatStatus

    /// The synthesized memberwise initializer is internal: only this module's
    /// resolvers construct a `ResolvedDay`, which is what guarantees `weekday`
    /// is the real weekday of `gregorian` and that a supported status is in
    /// range.
}

/// Why a day could not be resolved. Every case is invalid input or a defect.
/// An unsupported Bikram Sambat date is a normal `ResolvedDay` boundary, never
/// one of these — the distinction the glossary requires.
public enum DayResolutionError: Error, Sendable, Hashable {
    /// The components do not name a real Gregorian civil day (February 30,
    /// month 13, day 0). `Calendar` would silently normalize these; the
    /// resolver rejects them instead.
    case invalidCivilDay(GADay)

    /// The table failed to answer a day it claims to cover, or its supported
    /// bounds could not be derived: a broken dataset assumption, never a
    /// boundary.
    case datasetAssumptionFailure(GADay)

    /// Calendar arithmetic failed for an otherwise valid civil day. Defensive:
    /// unreachable while Foundation behaves.
    case calendarCalculationFailure(GADay)

    /// The Nepal Time civil day could not be read from the supplied instant.
    /// Defensive: unreachable while Foundation behaves.
    case unreadableInstant(Date)

    /// The Gregorian day this error carries as display context, when one was
    /// actually resolved. Failures that never derived a day supply nothing —
    /// an error display never invents a date.
    public var resolvedGregorianDay: GADay? {
        switch self {
        case .datasetAssumptionFailure(let day), .calendarCalculationFailure(let day):
            day
        case .invalidCivilDay, .unreadableInstant:
            nil
        }
    }
}

/// Whether the components name a real Gregorian civil day. The same
/// round-trip check `utcDate` applies before any conversion, so validation
/// lives in exactly one place.
func isValidCivilDay(_ ad: GADay) -> Bool {
    utcDate(from: ad) != nil
}

/// Resolves a Gregorian civil day to its `ResolvedDay`, or throws.
///
/// The boundary classification is derived from the dataset's exact Gregorian
/// bounds — never from a nil conversion, which would conflate "outside the
/// table" with "the table is broken".
public func resolvedDay(for ad: GADay, in dataset: CalendarDataset) throws -> ResolvedDay {
    guard isValidCivilDay(ad) else {
        throw DayResolutionError.invalidCivilDay(ad)
    }
    guard let weekdayValue = weekday(of: ad) else {
        throw DayResolutionError.calendarCalculationFailure(ad)
    }
    guard let start = dataset.gregorianStart else {
        throw DayResolutionError.datasetAssumptionFailure(ad)
    }
    if ad < start {
        return ResolvedDay(gregorian: ad, weekday: weekdayValue, bikramSambat: .beforeSupportedRange)
    }
    guard let end = dataset.gregorianEnd else {
        throw DayResolutionError.datasetAssumptionFailure(ad)
    }
    if ad > end {
        return ResolvedDay(gregorian: ad, weekday: weekdayValue, bikramSambat: .afterSupportedRange)
    }
    guard let bs = adToBS(ad, in: dataset) else {
        throw DayResolutionError.datasetAssumptionFailure(ad)
    }
    return ResolvedDay(gregorian: ad, weekday: weekdayValue, bikramSambat: .supported(bs))
}

/// Resolves the Nepal Time civil day of a supplied instant and its
/// `ResolvedDay`, or throws. The instant is supplied — the clock is read once
/// by the caller and never inside core.
public func resolvedDay(now: Date, in dataset: CalendarDataset) throws -> ResolvedDay {
    guard let ad = todayAD(now: now) else {
        throw DayResolutionError.unreadableInstant(now)
    }
    return try resolvedDay(for: ad, in: dataset)
}
