// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Dibas Sigdel
import Foundation
import NepalKitCore

extension DisplaySettings {
    /// The Watch's only display configuration: Nepali names, Devanagari digits.
    public static let watch = DisplaySettings(digits: .devanagari, monthNames: .nepali)
}

/// The display pieces of one supported day, plus speech strings.
///
/// Speech uses Latin digits and transliterated names: watchOS VoiceOver voices
/// skip Devanagari month names entirely.
public struct WatchDayComponents: Sendable, Hashable {
    public let weekdayName: String
    public let bikramSambatDay: String
    public let bikramSambatMonthName: String
    public let bikramSambatYear: String
    public let gregorianDay: String
    public let gregorianMonthName: String
    public let gregorianYear: String

    public let spokenBikramSambat: String
    public let spokenWeekdayName: String
    public let spokenGregorian: String
}

/// The display pieces of a day outside the supported range.
public struct WatchBoundaryComponents: Sendable, Hashable {
    public enum Side: Sendable, Hashable {
        case before
        case after
    }

    public let side: Side

    /// The first or last supported BS year, in display digits.
    public let contextYear: String

    /// For example, `Supported from १९७५ BS`.
    public let contextLine: String

    public var compactContextLine: String {
        switch side {
        case .before: "From \(contextYear) BS"
        case .after: "Through \(contextYear) BS"
        }
    }

    public let gregorianDay: String
    public let gregorianMonthName: String
    public let gregorianYear: String

    public let spokenGregorian: String

    public let spokenDescription: String
}

/// The display pieces of a calculation failure. The Gregorian fields are nil
/// unless a day was actually resolved.
public struct WatchErrorComponents: Sendable, Hashable {
    public let gregorianDay: String?
    public let gregorianMonthName: String?
    public let gregorianYear: String?

    public let spokenGregorian: String?

    public var spokenDescription: String {
        guard let spokenGregorian else { return WatchDayCopy.failureFull }
        return "\(WatchDayCopy.failureFull)\n\(spokenGregorian)"
    }
}

/// What a Watch surface renders for one day.
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
        let weekday = BikramSambatDate.weekdayName(day.weekday, style: settings.monthNames) ?? String(day.weekday)
        let spokenWeekday = BikramSambatDate.weekdayName(day.weekday, style: .transliterated) ?? String(day.weekday)
        return .supported(WatchDayComponents(
            weekdayName: weekday,
            bikramSambatDay: settings.digits.format(bs.day),
            bikramSambatMonthName: BikramSambatDate.monthName(bs.month, style: settings.monthNames),
            bikramSambatYear: settings.digits.format(bs.year),
            gregorianDay: settings.digits.format(day.gregorian.day),
            gregorianMonthName: GregorianDate.monthName(day.gregorian.month),
            gregorianYear: settings.digits.format(day.gregorian.year),
            spokenBikramSambat: SpokenDate.bikramSambat(bs, monthNames: .transliterated),
            spokenWeekdayName: spokenWeekday,
            spokenGregorian: SpokenDate.gregorian(day.gregorian)
        ))
    case .beforeSupportedRange:
        return .rangeBoundary(boundary(.before, settings: settings, in: dataset, for: day))
    case .afterSupportedRange:
        return .rangeBoundary(boundary(.after, settings: settings, in: dataset, for: day))
    }
}

/// Resolves the Nepal Time day at `instant` and builds its display, mapping a
/// resolution failure to the calculation-error display.
public func watchDayDisplay(
    now instant: Date,
    settings: DisplaySettings,
    in dataset: CalendarDataset
) -> WatchDayDisplay {
    do {
        let day = try ResolvedDay(now: instant, in: dataset)
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

/// Resolves a Gregorian civil day and builds its display.
public func watchDayDisplay(
    for civilDay: GregorianDate,
    settings: DisplaySettings,
    in dataset: CalendarDataset
) -> WatchDayDisplay {
    do {
        let day = try ResolvedDay(civilDay, in: dataset)
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

/// Builds a calculation-error display.
public func watchCalculationErrorDisplay(
    gregorianDay: GregorianDate?,
    settings: DisplaySettings
) -> WatchDayDisplay {
    .calculationError(WatchErrorComponents(
        gregorianDay: gregorianDay.map { settings.digits.format($0.day) },
        gregorianMonthName: gregorianDay.map { GregorianDate.monthName($0.month) },
        gregorianYear: gregorianDay.map { settings.digits.format($0.year) },
        spokenGregorian: gregorianDay.map { SpokenDate.gregorian($0) }
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
    let contextYear = settings.digits.format(contextBSYear)
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
        gregorianDay: settings.digits.format(day.gregorian.day),
        gregorianMonthName: GregorianDate.monthName(day.gregorian.month),
        gregorianYear: settings.digits.format(day.gregorian.year),
        spokenGregorian: SpokenDate.gregorian(day.gregorian),
        spokenDescription: "\(WatchDayCopy.boundaryFull), \(spokenContext)"
    )
}

/// Status copy for the Watch's boundary and failure states.
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
