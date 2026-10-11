// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Dibas Sigdel
import NepalKitCore

extension SpokenDate {
    /// Today's date as one announcement: the Bikram Sambat date, then the
    /// Gregorian date and weekday. The popover shows the Gregorian side only in
    /// the month grid, so the hero's label carries both calendars.
    static func today(_ bs: BSDay, gregorian: GADay?, weekday: String?, monthNames: MonthNameStyle) -> String {
        let spokenBS = Self.bs(bs, monthNames: monthNames)
        guard let gregorian else { return spokenBS }
        return "\(spokenBS). \(gregorianAnnouncement(date: gregorian, weekday: weekday))"
    }
}
