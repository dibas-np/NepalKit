// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Dibas Sigdel
import Foundation

/// Complete display components of one supported day: what every Watch surface
/// composes from, plus the independent speech strings.
///
/// Core supplies the meaning so the app and the extension cannot drift; views
/// choose composition and layout only. Bikram Sambat pieces use canonical
/// Nepali names and the settings' digit script; Gregorian month names stay
/// English while their digits still honor the settings — the intentional mix
/// CONTEXT.md describes. Speech is independent of the visuals: Latin digits,
/// canonical Nepali names, and the complete year, whatever is fitted on
/// screen.
public struct WatchDayComponents: Sendable, Hashable {
    /// The resolved day's weekday, named per the settings. Shown once, no
    /// matter how many calendar representations the surface renders.
    public let weekdayName: String
    public let bikramSambatDay: String
    public let bikramSambatMonthName: String
    public let bikramSambatYear: String
    public let gregorianDay: String
    public let gregorianMonthName: String
    public let gregorianYear: String

    /// The spoken Bikram Sambat date, e.g. `11 असोज 2083`.
    public let spokenBikramSambat: String
    /// The spoken weekday — the same name the visuals show under the Watch's
    /// fixed settings, but carried separately so a future display change
    /// cannot silently change speech.
    public let spokenWeekdayName: String
    /// The spoken Gregorian date, for surfaces that present it.
    public let spokenGregorian: String
}

/// The display meaning of a range boundary: the expected "the Bikram Sambat
/// date is unavailable" result with its dataset-derived support context and
/// the Gregorian date that remains answerable.
public struct WatchBoundaryComponents: Sendable, Hashable {
    public enum Side: Sendable, Hashable {
        /// Before the dataset's first supported day: support is named from
        /// the first supported year.
        case before
        /// After the dataset's last supported day: support is named through
        /// the last supported year.
        case after
    }

    public let side: Side

    /// The boundary's context year — the first supported BS year before the
    /// range, the last one after it — rendered in the display digits.
    public let contextYear: String

    /// The composed support line in display digits, e.g.
    /// `Supported from १९७५ BS`.
    public let contextLine: String

    /// The Gregorian day the boundary belongs to; it remains answerable.
    public let gregorianDay: String
    public let gregorianMonthName: String
    public let gregorianYear: String

    /// The complete accessible description with Latin digits, e.g.
    /// `Bikram Sambat unavailable, supported from 1975 BS`. Support context is
    /// retained even where the visuals cannot fit it.
    public let spokenDescription: String
}

/// The display meaning of a calculation failure. Gregorian context appears
/// only when a Gregorian day was actually resolved; an error never invents
/// one.
public struct WatchErrorComponents: Sendable, Hashable {
    public let gregorianDay: String?
    public let gregorianMonthName: String?
    public let gregorianYear: String?
}

/// What a Watch surface renders for one day: a supported date, an expected
/// range boundary, or a calculation failure. The three states are distinct
/// values — color alone never carries the distinction, and no surface may
/// substitute one for another.
public enum WatchDayDisplay: Sendable, Hashable {
    case supported(WatchDayComponents)
    case rangeBoundary(WatchBoundaryComponents)
    case calculationError(WatchErrorComponents)
}

/// Builds the complete display meaning of a resolved day.
public func watchDayDisplay(
    for day: ResolvedDay,
    settings: DisplaySettings,
    in dataset: CalendarDataset
) -> WatchDayDisplay {
    switch day.bikramSambat {
    case .supported(let bs):
        let weekday = weekdayName(for: day.weekday, style: settings.monthNames) ?? String(day.weekday)
        return .supported(WatchDayComponents(
            weekdayName: weekday,
            bikramSambatDay: formatNumber(bs.day, digits: settings.digits),
            bikramSambatMonthName: monthName(month: bs.month, style: settings.monthNames),
            bikramSambatYear: formatNumber(bs.year, digits: settings.digits),
            gregorianDay: formatNumber(day.gregorian.day, digits: settings.digits),
            gregorianMonthName: gregorianMonthName(day.gregorian.month),
            gregorianYear: formatNumber(day.gregorian.year, digits: settings.digits),
            spokenBikramSambat: SpokenDate.bs(bs, monthNames: settings.monthNames),
            spokenWeekdayName: weekday,
            spokenGregorian: SpokenDate.ad(day.gregorian)
        ))
    case .beforeSupportedRange:
        return .rangeBoundary(boundary(.before, settings: settings, in: dataset, for: day))
    case .afterSupportedRange:
        return .rangeBoundary(boundary(.after, settings: settings, in: dataset, for: day))
    }
}

/// Builds a calculation-error display, carrying the Gregorian day only when
/// one was actually resolved.
public func watchCalculationErrorDisplay(
    gregorianDay: GADay?,
    settings: DisplaySettings
) -> WatchDayDisplay {
    .calculationError(WatchErrorComponents(
        gregorianDay: gregorianDay.map { formatNumber($0.day, digits: settings.digits) },
        gregorianMonthName: gregorianDay.map { gregorianMonthName($0.month) },
        gregorianYear: gregorianDay.map { formatNumber($0.year, digits: settings.digits) }
    ))
}

private func boundary(
    _ side: WatchBoundaryComponents.Side,
    settings: DisplaySettings,
    in dataset: CalendarDataset,
    for day: ResolvedDay
) -> WatchBoundaryComponents {
    let contextBSYear = switch side {
    case .before: dataset.supportedRange.lowerBound
    case .after: dataset.supportedRange.upperBound
    }
    let contextYear = formatNumber(contextBSYear, digits: settings.digits)
    let contextLine = switch side {
    case .before: "Supported from \(contextYear) BS"
    case .after: "Supported through \(contextYear) BS"
    }
    let spokenContext = switch side {
    case .before: "supported from \(contextBSYear) BS"
    case .after: "supported through \(contextBSYear) BS"
    }
    return WatchBoundaryComponents(
        side: side,
        contextYear: contextYear,
        contextLine: contextLine,
        gregorianDay: formatNumber(day.gregorian.day, digits: settings.digits),
        gregorianMonthName: gregorianMonthName(day.gregorian.month),
        gregorianYear: formatNumber(day.gregorian.year, digits: settings.digits),
        spokenDescription: "\(WatchDayCopy.boundaryFull), \(spokenContext)"
    )
}

/// The firm copy the Watch uses for its states, in one place. The accepted
/// presentation fixes these strings; the English status copy does not alter
/// the fixed Nepali month/weekday and Devanagari date presentation.
public enum WatchDayCopy {
    /// Range boundary, full presentation.
    public static let boundaryFull = "Bikram Sambat unavailable"
    /// Range boundary, compact presentation.
    public static let boundaryCompact = "Unavailable"
    /// Calculation failure, full presentation.
    public static let failureFull = "Date calculation failed"
    /// Calculation failure, compact presentation.
    public static let failureCompact = "Error"
}
