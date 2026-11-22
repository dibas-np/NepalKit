// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Dibas Sigdel
import NepalKitCore

/// Accessibility labels for complications. Compact labels still speak the
/// full BS date; weekday and Gregorian speech follow what is shown.
public enum ComplicationAccessibility {
    public static func supportedLabel(
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

    public static func boundaryLabel(_ boundary: WatchBoundaryComponents, gregorian: Bool = false) -> String {
        guard gregorian else { return boundary.spokenDescription }
        return "\(boundary.spokenDescription)\n\(boundary.spokenGregorian)"
    }
}
