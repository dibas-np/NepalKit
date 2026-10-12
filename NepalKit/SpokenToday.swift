// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Dibas Sigdel
import NepalKitCore

extension SpokenDate {
    /// Today's date as one announcement: the Bikram Sambat date, the Gregorian
    /// date and weekday, then today's festivals and any nationwide public
    /// holiday. The hero's label carries both calendars because the popover
    /// shows the Gregorian side only in the month grid, and the festival line
    /// under the hero is part of the same element.
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
