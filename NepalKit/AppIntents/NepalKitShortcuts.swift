// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Dibas Sigdel
import AppIntents

/// NepalKit's App Shortcuts. Conversions use parameterless phrases and let Siri ask
/// for the date: a `Date` can't appear in a phrase, and a month enum in one would
/// generate a shortcut per case against the ten-shortcut cap.
struct NepalKitShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: TodayInBikramSambatIntent(),
            phrases: [
                "What is today's Nepali date with \(.applicationName)",
                "What is my \(.applicationName) date",
                "What is today in Bikram Sambat with \(.applicationName)",
            ],
            shortTitle: "Today's Nepali date",
            systemImageName: "calendar"
        )
        AppShortcut(
            intent: TomorrowInBikramSambatIntent(),
            phrases: [
                "What is tomorrow's Nepali date with \(.applicationName)",
                "What is tomorrow in Bikram Sambat with \(.applicationName)",
            ],
            shortTitle: "Tomorrow's Nepali date",
            systemImageName: "calendar.badge.plus"
        )
        AppShortcut(
            intent: YesterdayInBikramSambatIntent(),
            phrases: [
                "What was yesterday's Nepali date with \(.applicationName)",
                "Yesterday's Bikram Sambat date in \(.applicationName)",
            ],
            shortTitle: "Yesterday's Nepali date",
            systemImageName: "calendar.badge.minus"
        )
        AppShortcut(
            intent: GregorianToBikramSambatIntent(),
            phrases: [
                "Convert a date to Bikram Sambat with \(.applicationName)",
                "Use \(.applicationName) to convert to Bikram Sambat",
            ],
            shortTitle: "Convert to Bikram Sambat",
            systemImageName: "arrow.left.arrow.right"
        )
        AppShortcut(
            intent: BikramSambatToGregorianIntent(),
            phrases: [
                "Convert a Bikram Sambat date to Gregorian with \(.applicationName)",
                "Use \(.applicationName) to convert from Bikram Sambat",
            ],
            shortTitle: "Convert to Gregorian",
            systemImageName: "arrow.left.arrow.right"
        )
    }
}
