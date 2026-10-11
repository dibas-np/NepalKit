// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Dibas Sigdel
import NepalKitCore

extension SpokenDate {
    /// Today's date as one announcement: the Bikram Sambat date, then the
    /// Gregorian date and weekday, then today's festivals and, on a nationwide
    /// public holiday, that it is one. The popover shows the Gregorian side
    /// only in the month grid, so the hero's label carries both calendars, and
    /// the festival line under the hero is part of the same element, so what
    /// it says is said here rather than on its own.
    static func today(
        _ bs: BSDay, gregorian: GADay?, weekday: String?, monthNames: MonthNameStyle, festivals: [Festival] = [],
        isPublicHoliday: Bool = false
    ) -> String {
        var sentences = [Self.bs(bs, monthNames: monthNames)]
        if let gregorian { sentences.append(gregorianAnnouncement(date: gregorian, weekday: weekday)) }
        let holiday = isPublicHoliday ? [Strings.publicHolidaySpoken(.nationwide, monthNames: monthNames)] : []
        let names = festivals.map { festival($0, monthNames: monthNames) } + holiday
        if !names.isEmpty { sentences.append(Strings.festivalNames(names)) }
        return sentences.joined(separator: ". ")
    }
}
