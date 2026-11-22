// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Dibas Sigdel
import AppIntents

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
            intent: RelativeDayInBikramSambatIntent(),
            phrases: [
                "What is \(\.$day)'s Nepali date with \(.applicationName)",
                "What was \(\.$day)'s Nepali date with \(.applicationName)",
                "What is \(\.$day) in Bikram Sambat with \(.applicationName)",
                "\(\.$day)'s Bikram Sambat date in \(.applicationName)",
            ],
            shortTitle: "Tomorrow or yesterday",
            systemImageName: "calendar.badge.clock"
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
