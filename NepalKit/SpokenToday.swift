// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Dibas Sigdel
import NepalKitCore

extension SpokenDate {
    /// Today's date as one announcement: the Bikram Sambat date, then the
    /// Gregorian date and weekday, then today's festivals. The popover shows
    /// the Gregorian side only in the month grid, so the hero's label carries
    /// both calendars, and the festival line under the hero is part of the
    /// same element, so its names are said here rather than on their own.
    static func today(
        _ bs: BSDay, gregorian: GADay?, weekday: String?, monthNames: MonthNameStyle, festivals: [Festival] = []
    ) -> String {
        var sentences = [Self.bs(bs, monthNames: monthNames)]
        if let gregorian { sentences.append(gregorianAnnouncement(date: gregorian, weekday: weekday)) }
        if !festivals.isEmpty {
            sentences.append(Strings.festivalNames(festivals.map { festival($0, monthNames: monthNames) }))
        }
        return sentences.joined(separator: ". ")
    }
}
