// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Dibas Sigdel
import AppIntents

/// NepalKit's App Shortcuts — ticket 02's today phrases, verbatim. Every
/// phrase carries the application-name token; the conversion shortcuts join
/// this provider in tickets 09 and 10, consuming these primitives rather than
/// establishing their own.
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
    }
}
