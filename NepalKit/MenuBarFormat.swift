// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Dibas Sigdel
import Foundation
import NepalKitCore

nonisolated struct MenuBarFormat: Sendable, Hashable {
    var showsWeekday: Bool
    var showsYear: Bool
    var showsTime: Bool
    var usesTwentyFourHourClock: Bool
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

nonisolated private func todayWeekday(now: Date, timeZone: TimeZone) -> Int? {
    GregorianDate.today(now: now, timeZone: timeZone).flatMap { ($0).weekday }
}

extension SpokenDate {
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
