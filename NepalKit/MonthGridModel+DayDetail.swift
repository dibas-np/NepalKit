// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Dibas Sigdel
import AppKit
import SwiftUI
import NepalKitCore

struct MonthGridDayDetail: Hashable {
    let bikramSambat: String
    let gregorian: String
    let relative: String?
    let spokenBikramSambat: String
    let spokenGregorian: String
    let spokenRelative: String?
    let festivals: [String]
    let spokenFestivals: [String]
    let holidays: [String]
}

extension MonthGridModel {
    func daysFromToday(_ day: MonthGridDay) -> Int? {
        guard let todayGregorian, let from = todayGregorian.noonUTC, let to = day.gregorian.noonUTC
        else { return nil }
        return Int((to.timeIntervalSince(from) / 86_400).rounded())
    }

    func detail(for day: MonthGridDay, settings: DisplaySettings) -> MonthGridDayDetail {
        let weekday = BikramSambatDate.weekdayName(day.weekday, style: settings.monthNames)
        let gregorian = day.gregorian.formatted(digits: settings.digits)
        let distance = daysFromToday(day)
        return MonthGridDayDetail(
            bikramSambat: day.bikramSambat.formatted(settings),
            gregorian: weekday.map { Strings.datedWithWeekday(gregorian, $0) } ?? gregorian,
            relative: distance.map { Strings.relativeDays($0, digits: settings.digits) },
            spokenBikramSambat: SpokenDate.bikramSambat(day.bikramSambat, monthNames: settings.monthNames),
            spokenGregorian: SpokenDate.gregorianAnnouncement(date: day.gregorian, weekday: weekday),
            spokenRelative: distance.map { Strings.relativeDays($0, digits: .latin) },
            festivals: day.festivals.map { $0.name(style: settings.monthNames) },
            spokenFestivals: day.festivals.map { SpokenDate.festival($0, monthNames: settings.monthNames) },
            holidays: day.holidayScopes.map { Strings.publicHoliday($0, monthNames: settings.monthNames) }
        )
    }

    func copy(_ detail: MonthGridDayDetail, to pasteboard: NSPasteboard = .general) {
        pasteboard.clearContents()
        pasteboard.setString(detail.bikramSambat, forType: .string)
    }

    func calendarEvent(for day: MonthGridDay, settings: DisplaySettings) -> CalendarEvent {
        let detail = detail(for: day, settings: settings)
        let title = detail.festivals.isEmpty ? detail.bikramSambat : detail.festivals.joined(separator: ", ")
        let notes = ([detail.bikramSambat + " · " + detail.gregorian] + detail.holidays).joined(separator: "\n")
        return CalendarEvent(title: title, notes: notes, date: day.gregorian)
    }

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
