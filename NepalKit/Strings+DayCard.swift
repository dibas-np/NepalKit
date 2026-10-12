// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Dibas Sigdel

/// The day card's Add to Calendar; apart so `Strings.swift` stays under the length limit.
nonisolated extension Strings {
    static let addToCalendarLabel = "Add to Calendar"
    static let addToCalendarHelp = "Opens this day as an all-day event in your calendar app"
    /// The event file could not be written or no calendar app opened it.
    static let addToCalendarFailed = "Couldn't open the event in a calendar app."
}
