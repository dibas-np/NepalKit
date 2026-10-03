// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Dibas Sigdel
import NepalKitCore

/// The accessibility labels each complication family announces, composed from
/// core speech so no view ever parses a fitted visual string.
///
/// The contract, from the accepted presentation: every supported compact view
/// exposes the complete Bikram Sambat date — Latin digits and the full year —
/// even where the visuals omit it, and one weekday, announced only when the
/// family shows one. Gregorian detail joins the label only when the surface
/// presents it; a fallback that omits Gregorian detail need not announce it.
enum ComplicationAccessibility {
    /// The supported-day label for a family that shows a weekday and/or the
    /// Gregorian date alongside the Bikram Sambat date.
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
        // Line breaks, not commas: VoiceOver announces commas aloud under
        // its default punctuation setting, and a break reads as a pause.
        return parts.joined(separator: "\n")
    }

    /// The boundary label: the full unavailable statement with its
    /// dataset-derived support context, even where compact visuals cannot fit
    /// the context.
    static func boundaryLabel(_ boundary: WatchBoundaryComponents, gregorian: Bool = false) -> String {
        guard gregorian else { return boundary.spokenDescription }
        return "\(boundary.spokenDescription)\n\(boundary.spokenGregorian)"
    }

    /// The failure label: the full error statement plus the spoken Gregorian
    /// date only when one was actually resolved — never an invented date, and
    /// always Latin digits in speech.
    static func errorLabel(_ components: WatchErrorComponents) -> String {
        components.spokenDescription
    }
}
