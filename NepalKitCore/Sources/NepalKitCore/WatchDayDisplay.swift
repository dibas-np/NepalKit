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
/// transliterated month and weekday names, and the complete year, whatever is
/// fitted on screen. The first on-device session (2026-10-03) found the
/// watch's VoiceOver voices skipping Devanagari month names entirely, so
/// transliterated names — which every voice reads — carry the spoken meaning
/// while the visuals keep the canonical Devanagari script.
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
    /// The spoken weekday, transliterated so every voice reads it — carried
    /// separately from the visual weekday, which stays in the canonical
    /// script.
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

    /// Support context for a compact complication, preserving the bound and year.
    public var compactContextLine: String {
        switch side {
        case .before: "From \(contextYear) BS"
        case .after: "Through \(contextYear) BS"
        }
    }

    /// The Gregorian day the boundary belongs to; it remains answerable.
    public let gregorianDay: String
    public let gregorianMonthName: String
    public let gregorianYear: String

    /// The resolved Gregorian date formatted for speech with Latin digits.
    public let spokenGregorian: String

    /// The unavailable statement and support context, spoken with Latin digits.
    public let spokenDescription: String
}

/// The display meaning of a calculation failure. Gregorian context appears
/// only when a Gregorian day was actually resolved; an error never invents
/// one.
public struct WatchErrorComponents: Sendable, Hashable {
    public let gregorianDay: String?
    public let gregorianMonthName: String?
    public let gregorianYear: String?

    /// The spoken form of the resolved Gregorian date with Latin digits, for
    /// accessibility compositions. nil when no day was resolved — speech
    /// never reads the visual Devanagari digits.
    public let spokenGregorian: String?

    /// The failure statement and any resolved Gregorian date, formatted for speech.
    public var spokenDescription: String {
        guard let spokenGregorian else { return WatchDayCopy.failureFull }
        return "\(WatchDayCopy.failureFull)\n\(spokenGregorian)"
    }
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
        let spokenWeekday = weekdayName(for: day.weekday, style: .transliterated) ?? String(day.weekday)
        return .supported(WatchDayComponents(
            weekdayName: weekday,
            bikramSambatDay: formatNumber(bs.day, digits: settings.digits),
            bikramSambatMonthName: monthName(month: bs.month, style: settings.monthNames),
            bikramSambatYear: formatNumber(bs.year, digits: settings.digits),
            gregorianDay: formatNumber(day.gregorian.day, digits: settings.digits),
            gregorianMonthName: gregorianMonthName(day.gregorian.month),
            gregorianYear: formatNumber(day.gregorian.year, digits: settings.digits),
            spokenBikramSambat: SpokenDate.bs(bs, monthNames: .transliterated),
            spokenWeekdayName: spokenWeekday,
            spokenGregorian: SpokenDate.ad(day.gregorian)
        ))
    case .beforeSupportedRange:
        return .rangeBoundary(boundary(.before, settings: settings, in: dataset, for: day))
    case .afterSupportedRange:
        return .rangeBoundary(boundary(.after, settings: settings, in: dataset, for: day))
    }
}

/// Resolves the Nepal Time day of the supplied instant and builds its display
/// meaning in one step, mapping a resolution failure to the calculation-error
/// display. The error carries the Gregorian day only when one was actually
/// resolved — never an invented date. Never throws: the display states are
/// exhaustive.
public func watchDayDisplay(
    now instant: Date,
    settings: DisplaySettings,
    in dataset: CalendarDataset
) -> WatchDayDisplay {
    do {
        let day = try resolvedDay(now: instant, in: dataset)
        return watchDayDisplay(for: day, settings: settings, in: dataset)
    } catch let error as DayResolutionError {
        return watchCalculationErrorDisplay(
            gregorianDay: error.resolvedGregorianDay,
            settings: settings
        )
    } catch {
        return watchCalculationErrorDisplay(gregorianDay: nil, settings: settings)
    }
}

/// Resolves a Gregorian civil day and builds its display meaning in one step,
/// with the same failure mapping as the instant-based variant.
public func watchDayDisplay(
    for civilDay: GADay,
    settings: DisplaySettings,
    in dataset: CalendarDataset
) -> WatchDayDisplay {
    do {
        let day = try resolvedDay(for: civilDay, in: dataset)
        return watchDayDisplay(for: day, settings: settings, in: dataset)
    } catch let error as DayResolutionError {
        return watchCalculationErrorDisplay(
            gregorianDay: error.resolvedGregorianDay,
            settings: settings
        )
    } catch {
        return watchCalculationErrorDisplay(gregorianDay: nil, settings: settings)
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
        gregorianYear: gregorianDay.map { formatNumber($0.year, digits: settings.digits) },
        spokenGregorian: gregorianDay.map { SpokenDate.ad($0) }
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
        spokenGregorian: SpokenDate.ad(day.gregorian),
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
