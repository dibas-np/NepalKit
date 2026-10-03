// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Dibas Sigdel
import NepalKitCore

/// Builds complication labels from core speech using Latin digits.
/// Compact labels retain the full BS date. Weekday and Gregorian speech
/// follow the visible content.
enum ComplicationAccessibility {
    /// Includes the weekday and Gregorian date when displayed.
    static func supportedLabel(
        _ components: WatchDayComponents,
        weekday: Bool,
        gregorian: Bool
    ) -> String {
        var parts: [String] = []
        if weekday {
            parts.append(components.spokenWeekdayName)
        }
        parts.append(components.spokenBikramSambat)
        if gregorian {
            parts.append(components.spokenGregorian)
        }
        // Newlines pause speech without announcing comma punctuation.
        return parts.joined(separator: "\n")
    }

    /// Retains support context and includes Gregorian speech when displayed.
    static func boundaryLabel(_ boundary: WatchBoundaryComponents, gregorian: Bool = false) -> String {
        guard gregorian else { return boundary.spokenDescription }
        return "\(boundary.spokenDescription)\n\(boundary.spokenGregorian)"
    }
}
