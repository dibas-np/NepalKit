// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Dibas Sigdel
import Foundation
import NepalKitCore

/// Optional parts of the menu-bar title, after the macOS menu-bar clock's options.
nonisolated struct MenuBarFormat: Sendable, Hashable {
    /// The short weekday name before the date ("Mon", "सोम").
    var showsWeekday: Bool
    /// The Bikram Sambat year after the month ("25 Ashoj 2083").
    var showsYear: Bool
    /// The clock at the end of the title, in the zone the title is read in.
    var showsTime: Bool
    /// "22:57" rather than "10:57". Only meaningful with `showsTime`.
    var usesTwentyFourHourClock: Bool
    /// Seconds on the clock. Only meaningful with `showsTime`.
    var showsSeconds: Bool

    init(
        showsWeekday: Bool = false,
        showsYear: Bool = false,
        showsTime: Bool = false,
        usesTwentyFourHourClock: Bool = false,
        showsSeconds: Bool = false
    ) {
        self.showsWeekday = showsWeekday
        self.showsYear = showsYear
        self.showsTime = showsTime
        self.usesTwentyFourHourClock = usesTwentyFourHourClock
        self.showsSeconds = showsSeconds
    }

    static let standard = MenuBarFormat()
}

/// The menu-bar title for `now`, or nil outside the supported range. Every part is
/// read from the one instant so they cannot disagree around midnight.
nonisolated func formatMenuBarTitle(
    now: Date,
    timeZone: TimeZone = .nepal,
    format: MenuBarFormat,
    settings: DisplaySettings,
    in dataset: CalendarDataset
) -> String? {
    guard let today = BikramSambatDate.today(now: now, timeZone: timeZone, in: dataset) else { return nil }
    var parts: [String] = []
    if format.showsWeekday, let name = todayWeekday(now: now, timeZone: timeZone).flatMap({ BikramSambatDate.shortWeekdayName($0, style: settings.monthNames) }) {
        parts.append(name)
    }
    parts.append(format.showsYear ? today.formatted(settings) : today.formatted(settings, includesYear: false))
    if format.showsTime {
        parts.append(settings.digits.formatTime(
            now,
            in: timeZone,
            twentyFourHour: format.usesTwentyFourHourClock,
            showsSeconds: format.showsSeconds
        ))
    }
    return parts.joined(separator: " ")
}

/// Today's weekday in `timeZone`, 1 (Sunday) through 7 (Saturday).
nonisolated private func todayWeekday(now: Date, timeZone: TimeZone) -> Int? {
    GregorianDate.today(now: now, timeZone: timeZone).flatMap { ($0).weekday }
}

extension SpokenDate {
    /// The spoken form of `formatMenuBarTitle`. Always includes the year:
    /// `showsYear` only saves menu-bar width.
    nonisolated static func menuBarDate(
        now: Date,
        timeZone: TimeZone = .nepal,
        format: MenuBarFormat,
        monthNames: MonthNameStyle,
        in dataset: CalendarDataset
    ) -> String? {
        guard let today = BikramSambatDate.today(now: now, timeZone: timeZone, in: dataset) else { return nil }
        var parts: [String] = []
        if format.showsWeekday, let name = todayWeekday(now: now, timeZone: timeZone).flatMap({ BikramSambatDate.weekdayName($0, style: monthNames) }) {
            parts.append(name)
        }
        parts.append(bikramSambat(today, monthNames: monthNames))
        if format.showsTime {
            let time = DigitScript.latin.formatTime(
                now,
                in: timeZone,
                twentyFourHour: format.usesTwentyFourHourClock,
                showsSeconds: format.showsSeconds
            )
            // A listener cannot glance to tell AM from PM.
            if format.usesTwentyFourHourClock {
                parts.append(time)
            } else {
                var calendar = Calendar(identifier: .gregorian)
                calendar.timeZone = timeZone
                let hour = calendar.component(.hour, from: now)
                parts.append(time + (hour < 12 ? " AM" : " PM"))
            }
        }
        return parts.joined(separator: ", ")
    }
}
