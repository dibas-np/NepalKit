// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Dibas Sigdel
import Foundation

/// Which optional parts the menu-bar title carries beside the Bikram Sambat
/// date, modelled on the macOS menu-bar clock's options. Every option defaults
/// off, so `.standard` is the original short "day month" title.
public struct MenuBarFormat: Sendable, Hashable {
    /// The short weekday name before the date ("Mon", "सोम").
    public var showsWeekday: Bool
    /// The Bikram Sambat year after the month ("25 Ashoj 2083").
    public var showsYear: Bool
    /// The clock at the end of the title, in the zone the title is read in.
    public var showsTime: Bool
    /// "22:57" rather than "10:57". Only meaningful with `showsTime`.
    public var usesTwentyFourHourClock: Bool
    /// Seconds on the clock. Only meaningful with `showsTime`.
    public var showsSeconds: Bool

    public init(
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

    /// The title the menu bar showed before any of these options existed.
    public static let standard = MenuBarFormat()
}

/// Formats a clock time in the given zone, honoring the digit-script setting.
///
/// The 12-hour form has no AM/PM, like the macOS menu-bar clock: a glance
/// tells morning from evening, and there is no established Nepali marker to pair
/// with Devanagari digits. `SpokenDate.menuBarDate` adds it for listeners. The
/// 12-hour hour is unpadded ("9:05"); the 24-hour one is padded ("09:05").
public func formatClockTime(
    _ date: Date,
    timeZone: TimeZone,
    usesTwentyFourHourClock: Bool,
    showsSeconds: Bool,
    digits: DigitScript
) -> String {
    let calendar = ClockCalendars.gregorian(timeZone: timeZone)
    // `component(_:from:)` is non-optional, unlike `dateComponents`.
    let hour24 = calendar.component(.hour, from: date)
    let hour: String
    if usesTwentyFourHourClock {
        hour = twoDigits(hour24, digits: digits)
    } else {
        // 0 and 12 both read 12 on a 12-hour clock.
        hour = formatNumber(hour24 % 12 == 0 ? 12 : hour24 % 12, digits: digits)
    }
    let minute = twoDigits(calendar.component(.minute, from: date), digits: digits)
    guard showsSeconds else { return "\(hour):\(minute)" }
    return "\(hour):\(minute):\(twoDigits(calendar.component(.second, from: date), digits: digits))"
}

/// The menu-bar title for the instant `now`: weekday, date, year, time, each
/// part present only if the format asks for it, in that fixed order.
///
/// Every part is read in `timeZone` (default Nepal Time; ADR-0017) from the
/// one instant, so the parts cannot disagree around midnight. Nil outside the
/// supported range.
public func formatMenuBarTitle(
    now: Date,
    timeZone: TimeZone = nepalTimeZone,
    format: MenuBarFormat,
    settings: DisplaySettings,
    in dataset: CalendarDataset
) -> String? {
    guard let today = todayBS(now: now, timeZone: timeZone, in: dataset) else { return nil }
    var parts: [String] = []
    if format.showsWeekday, let name = todayWeekday(now: now, timeZone: timeZone).flatMap({ shortWeekdayName(for: $0, style: settings.monthNames) }) {
        parts.append(name)
    }
    parts.append(format.showsYear ? formatBS(today, settings: settings) : formatBSShort(today, settings: settings))
    if format.showsTime {
        parts.append(formatClockTime(
            now,
            timeZone: timeZone,
            usesTwentyFourHourClock: format.usesTwentyFourHourClock,
            showsSeconds: format.showsSeconds,
            digits: settings.digits
        ))
    }
    return parts.joined(separator: " ")
}

/// Today's weekday in `timeZone`, 1 (Sunday) through 7 (Saturday).
private func todayWeekday(now: Date, timeZone: TimeZone) -> Int? {
    todayAD(now: now, timeZone: timeZone).flatMap { weekday(of: $0) }
}

extension SpokenDate {
    /// The spoken form of `formatMenuBarTitle`: the same parts in order, with
    /// Latin digits and the full weekday name, since a voice may spell out "Mon".
    /// The year is always included, like every spoken Bikram Sambat date:
    /// `showsYear` exists to save menu-bar width, which does not apply aloud.
    public static func menuBarDate(
        now: Date,
        timeZone: TimeZone = nepalTimeZone,
        format: MenuBarFormat,
        monthNames: MonthNameStyle,
        in dataset: CalendarDataset
    ) -> String? {
        guard let today = todayBS(now: now, timeZone: timeZone, in: dataset) else { return nil }
        var parts: [String] = []
        if format.showsWeekday, let name = todayWeekday(now: now, timeZone: timeZone).flatMap({ weekdayName(for: $0, style: monthNames) }) {
            parts.append(name)
        }
        parts.append(bs(today, monthNames: monthNames))
        if format.showsTime {
            let time = formatClockTime(
                now,
                timeZone: timeZone,
                usesTwentyFourHourClock: format.usesTwentyFourHourClock,
                showsSeconds: format.showsSeconds,
                digits: .latin
            )
            // Spoken only: a listener cannot glance to tell AM from PM.
            if format.usesTwentyFourHourClock {
                parts.append(time)
            } else {
                let hour = ClockCalendars.gregorian(timeZone: timeZone).component(.hour, from: now)
                parts.append(time + (hour < 12 ? " AM" : " PM"))
            }
        }
        return parts.joined(separator: ", ")
    }
}
