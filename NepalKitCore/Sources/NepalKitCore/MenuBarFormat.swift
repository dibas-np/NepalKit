// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Dibas Sigdel
import Foundation

/// Which optional parts the menu-bar title carries beside the Bikram Sambat
/// date, modelled on the options of the macOS menu-bar clock.
///
/// Every option defaults off, so `.standard` is the short "day month" title the
/// menu bar has always shown, and a user who never opens the Menu Bar tab sees
/// no change.
public struct MenuBarFormat: Sendable, Hashable {
    /// The short weekday name before the date ("Mon", "सोम").
    public var showsWeekday: Bool
    /// The Bikram Sambat year after the month ("25 Ashoj 2083").
    public var showsYear: Bool
    /// The Nepal Time clock at the end of the title.
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
/// The 12-hour form carries no AM/PM, as the macOS menu-bar clock does not:
/// the menu bar is read at a glance by someone who knows whether it is morning,
/// and there is no existing Nepali form of the marker to pair with Devanagari
/// digits. Its hour has no leading zero ("9:05"); the 24-hour form pads it
/// ("09:05"), which is how both clock styles are conventionally written.
public func formatClockTime(
    _ date: Date,
    timeZone: TimeZone,
    usesTwentyFourHourClock: Bool,
    showsSeconds: Bool,
    digits: DigitScript
) -> String {
    let calendar = ClockCalendars.gregorian(timeZone: timeZone)
    // `component(_:from:)` rather than `dateComponents`: it is non-optional,
    // so there is no unreachable `?? 0` fallback for each field.
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
/// Every part is read in Nepal Time from the one instant, so the weekday, the
/// date and the clock cannot disagree with each other around midnight, and none
/// of them follows the Mac's own time zone. Nil past the supported range, where
/// there is no Bikram Sambat date to anchor the title.
public func formatMenuBarTitle(
    now: Date,
    format: MenuBarFormat,
    settings: DisplaySettings,
    in dataset: CalendarDataset
) -> String? {
    guard let today = todayBS(now: now, in: dataset) else { return nil }
    var parts: [String] = []
    if format.showsWeekday, let name = nepalTimeWeekday(now: now).flatMap({ shortWeekdayName(for: $0, style: settings.monthNames) }) {
        parts.append(name)
    }
    parts.append(format.showsYear ? formatBS(today, settings: settings) : formatBSShort(today, settings: settings))
    if format.showsTime {
        parts.append(formatClockTime(
            now,
            timeZone: nepalTimeZone,
            usesTwentyFourHourClock: format.usesTwentyFourHourClock,
            showsSeconds: format.showsSeconds,
            digits: settings.digits
        ))
    }
    return parts.joined(separator: " ")
}

/// Today's weekday in Nepal Time, 1 (Sunday) through 7 (Saturday).
private func nepalTimeWeekday(now: Date) -> Int? {
    todayAD(now: now).flatMap { weekday(of: $0) }
}

extension SpokenDate {
    /// The spoken form of `formatMenuBarTitle`: the same parts in the same
    /// order, with Latin digits and the weekday's full name, because a short
    /// form like "Mon" is an abbreviation a voice may spell out.
    ///
    /// The date always carries its year, whatever `showsYear` says, as every
    /// spoken Bikram Sambat date does: the year costs a voice nothing to say
    /// and the visual reason for dropping it — menu-bar width — does not apply.
    public static func menuBarDate(
        now: Date,
        format: MenuBarFormat,
        monthNames: MonthNameStyle,
        in dataset: CalendarDataset
    ) -> String? {
        guard let today = todayBS(now: now, in: dataset) else { return nil }
        var parts: [String] = []
        if format.showsWeekday, let name = nepalTimeWeekday(now: now).flatMap({ weekdayName(for: $0, style: monthNames) }) {
            parts.append(name)
        }
        parts.append(bs(today, monthNames: monthNames))
        if format.showsTime {
            parts.append(formatClockTime(
                now,
                timeZone: nepalTimeZone,
                usesTwentyFourHourClock: format.usesTwentyFourHourClock,
                showsSeconds: format.showsSeconds,
                digits: .latin
            ))
        }
        return parts.joined(separator: ", ")
    }
}
