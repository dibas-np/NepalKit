// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Dibas Sigdel

/// Builds complication labels from core speech using Latin digits.
/// Compact labels retain the full BS date. Weekday and Gregorian speech
/// follow the visible content.
///
/// **In core because the two watchOS products cannot share a framework target.**
/// The Watch app and its complication extension each need these labels, neither
/// can see the other's files, and both already link `NepalKitCore` — so core is
/// the one place a helper they must agree on byte for byte can live. `WatchDayCopy`
/// sits here for the same reason, and `CODING_STANDARDS.md`'s Watch exception
/// records that reasoning. Left in the extension, the Watch app's copy of a label
/// is a hand-rolled duplicate of the lines below, and the two drift silently: the
/// extension's suite keeps passing against its own copy while the app announces
/// something else.
public enum ComplicationAccessibility {
    /// Includes the weekday and Gregorian date when displayed.
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

    /// Retains support context and includes Gregorian speech when displayed.
    public static func boundaryLabel(_ boundary: WatchBoundaryComponents, gregorian: Bool = false) -> String {
        guard gregorian else { return boundary.spokenDescription }
        return "\(boundary.spokenDescription)\n\(boundary.spokenGregorian)"
    }
}
