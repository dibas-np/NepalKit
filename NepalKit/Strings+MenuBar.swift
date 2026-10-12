// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Dibas Sigdel

/// The Menu Bar tab's format options, in a file of their own so
/// `Strings.swift` stays under the length limit. Worded after the macOS
/// menu-bar clock's own options, which is where a user has met them before.
nonisolated extension Strings {
    static let menuBarFormatSection = "Format"
    static let menuBarShowsWeekday = "Show day of the week"
    static let menuBarShowsYear = "Show year"
    static let menuBarShowsTime = "Show time"
    static let menuBarUsesTwentyFourHourClock = "Use a 24-hour clock"
    static let menuBarShowsSeconds = "Show seconds"
}
