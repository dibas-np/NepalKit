// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Dibas Sigdel
import AppKit
import SwiftUI
import NepalKitCore

/// What the popover opened from a day shows, on both channels. Built by the
/// model so the view only lays it out, and so the shown and spoken halves come
/// from one date and cannot describe different days.
struct MonthGridDayDetail: Hashable {
    /// The full Bikram Sambat date as configured; also what Copy puts on the
    /// pasteboard, so what is copied is exactly what was read.
    let bikramSambat: String
    /// The full Gregorian date with its weekday.
    let gregorian: String
    /// How far the day is from today: "Today", "In 5 days". Nil only if
    /// today's Gregorian day could not be read.
    let relative: String?
    let spokenBikramSambat: String
    let spokenGregorian: String
    let spokenRelative: String?
    /// The day's festivals and national days by name, in the month-name
    /// setting; empty when there are none.
    let festivals: [String]
    let spokenFestivals: [String]
    /// Who the day is a public holiday for, one line per scope in the
    /// month-name setting's language; empty on a working day. Shown and
    /// spoken alike, as there are no digits in them.
    let holidays: [String]
}

/// The day's details, in a file of their own so the grid's model stays short.
extension MonthGridModel {
    /// Whole civil days from today to `day`: 0 for today, negative before it.
    /// Nil only if today's Gregorian day is unknown.
    func daysFromToday(_ day: MonthGridDay) -> Int? {
        // Both instants are noon UTC on their civil day, so their difference is
        // an exact multiple of a day; rounding only absorbs floating point.
        guard let todayGregorian, let from = noonUTC(for: todayGregorian), let to = noonUTC(for: day.gregorian)
        else { return nil }
        return Int((to.timeIntervalSince(from) / 86_400).rounded())
    }

    /// The popover's content for a day, shown as configured and spoken with
    /// Latin digits (`SpokenDate`'s rule).
    func detail(for day: MonthGridDay, settings: DisplaySettings) -> MonthGridDayDetail {
        let weekday = weekdayName(for: day.weekday, style: settings.monthNames)
        let gregorian = formatAD(day.gregorian, settings: settings)
        let distance = daysFromToday(day)
        return MonthGridDayDetail(
            bikramSambat: formatBS(day.bikramSambat, settings: settings),
            gregorian: weekday.map { Strings.datedWithWeekday(gregorian, $0) } ?? gregorian,
            relative: distance.map { Strings.relativeDays($0, digits: settings.digits) },
            spokenBikramSambat: SpokenDate.bs(day.bikramSambat, monthNames: settings.monthNames),
            spokenGregorian: SpokenDate.gregorianAnnouncement(date: day.gregorian, weekday: weekday),
            spokenRelative: distance.map { Strings.relativeDays($0, digits: .latin) },
            festivals: day.festivals.map { $0.name(style: settings.monthNames) },
            spokenFestivals: day.festivals.map { SpokenDate.festival($0, monthNames: settings.monthNames) },
            holidays: day.holidayScopes.map { Strings.publicHoliday($0, monthNames: settings.monthNames) }
        )
    }

    /// Copy: the Bikram Sambat date exactly as the popover shows it. The
    /// pasteboard is a parameter so a test can use a private one.
    func copy(_ detail: MonthGridDayDetail, to pasteboard: NSPasteboard = .general) {
        pasteboard.clearContents()
        pasteboard.setString(detail.bikramSambat, forType: .string)
    }

    /// The day as an all-day calendar event. Titled by its festivals when it
    /// has any, otherwise by its Bikram Sambat date; the notes carry both
    /// calendars' dates and any holiday, so the event says which day it was
    /// in Nepal's calendar however the calendar app shows it.
    func calendarEvent(for day: MonthGridDay, settings: DisplaySettings) -> CalendarEvent {
        let detail = detail(for: day, settings: settings)
        let title = detail.festivals.isEmpty ? detail.bikramSambat : detail.festivals.joined(separator: ", ")
        let notes = ([detail.bikramSambat + " · " + detail.gregorian] + detail.holidays).joined(separator: "\n")
        return CalendarEvent(title: title, notes: notes, date: day.gregorian)
    }

    /// Adds `day` to the calendar app; false when it did not get there. On a
    /// failure it also announces it: the card's message appears below the
    /// buttons, where VoiceOver is not, so the press is not met with silence.
    /// `open` and `announce` are injected so a test can stand in for the
    /// calendar app and hear the announcement instead of VoiceOver.
    func addToCalendar(
        _ day: MonthGridDay, settings: DisplaySettings,
        open: (CalendarEvent) -> Bool = { $0.open() },
        announce: (String) -> Void = { AccessibilityNotification.Announcement($0).post() }
    ) -> Bool {
        let added = open(calendarEvent(for: day, settings: settings))
        if !added { announce(Strings.addToCalendarFailed) }
        return added
    }
}
