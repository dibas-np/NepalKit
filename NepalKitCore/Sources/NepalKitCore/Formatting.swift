// SPDX-License-Identifier: MIT
// Copyright (C) 2026 Dibas Sigdel
import Foundation

/// The digits numbers are written in.
public enum DigitScript: String, Sendable, Hashable, Codable, CaseIterable {
    /// 0123456789
    case latin
    /// ०१२३४५६७८९
    case devanagari
}

/// The language Bikram Sambat month names and weekday names are written in.
/// Gregorian month names are always English.
public enum MonthNameStyle: String, Sendable, Hashable, Codable, CaseIterable {
    /// Nepali names in Devanagari: बैशाख, आइत.
    case nepali
    /// Transliterated month names and English weekday names: Baisakh, Sunday.
    case transliterated
}

/// How dates are written: the digits and the month-name style, chosen
/// independently.
public struct DisplaySettings: Sendable, Hashable, Codable {
    public let digits: DigitScript
    public let monthNames: MonthNameStyle

    public init(digits: DigitScript, monthNames: MonthNameStyle) {
        self.digits = digits
        self.monthNames = monthNames
    }
}

private let devanagariDigits: [Character] = ["०", "१", "२", "३", "४", "५", "६", "७", "८", "९"]

extension DigitScript {
    /// A number written in this script: `DigitScript.devanagari.format(2083)`
    /// is "२०८३". A minus sign is kept.
    public func format(_ value: Int) -> String {
        render(latinDigits: String(value))
    }

    /// The clock time at `date` in `timeZone`, written in this script.
    ///
    /// The 24-hour form pads the hour ("09:05"); the 12-hour form does not
    /// ("9:05") and carries no AM or PM marker, since there is no established
    /// Nepali one to pair with Devanagari digits.
    public func formatTime(
        _ date: Date,
        in timeZone: TimeZone = .nepal,
        twentyFourHour: Bool = true,
        showsSeconds: Bool = true
    ) -> String {
        let calendar = ClockCalendars.gregorian(timeZone: timeZone)
        // `component(_:from:)` is non-optional, unlike `dateComponents`.
        let hour24 = calendar.component(.hour, from: date)
        // 0 and 12 both read 12 on a 12-hour clock.
        let hour = twentyFourHour ? twoDigits(hour24) : format(hour24 % 12 == 0 ? 12 : hour24 % 12)
        let minute = twoDigits(calendar.component(.minute, from: date))
        guard showsSeconds else { return "\(hour):\(minute)" }
        return "\(hour):\(minute):\(twoDigits(calendar.component(.second, from: date)))"
    }

    /// Renders a Latin-digit string in this script. Only ASCII digits change:
    /// anything else, such as a minus sign, passes through, because dropping it
    /// would change the value.
    func render(latinDigits: String) -> String {
        switch self {
        case .latin:
            return latinDigits
        case .devanagari:
            return String(latinDigits.map { character in
                guard character.isASCII,
                      let value = character.wholeNumberValue,
                      devanagariDigits.indices.contains(value)
                else { return character }
                return devanagariDigits[value]
            })
        }
    }

    private func twoDigits(_ value: Int) -> String {
        render(latinDigits: value < 10 ? "0\(value)" : String(value))
    }
}

private let transliteratedMonthNames = [
    "Baisakh", "Jestha", "Ashar", "Shrawan", "Bhadra", "Ashoj",
    "Kartik", "Mangsir", "Poush", "Magh", "Falgun", "Chaitra",
]

private let nepaliMonthNames = [
    "बैशाख", "जेठ", "असार", "साउन", "भदौ", "असोज",
    "कात्तिक", "मंसिर", "पुस", "माघ", "फागुन", "चैत",
]

private let nepaliWeekdayNames = [
    "आइत", "सोम", "मंगल", "बुध", "बिही", "शुक्र", "शनि",
]

private let englishWeekdayNames = [
    "Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday",
]

private let gregorianMonthNames = [
    "January", "February", "March", "April", "May", "June",
    "July", "August", "September", "October", "November", "December",
]

extension BikramSambatDate {
    /// The twelve month names, Baisakh through Chaitra.
    public static func monthNames(style: MonthNameStyle) -> [String] {
        switch style {
        case .nepali: nepaliMonthNames
        case .transliterated: transliteratedMonthNames
        }
    }

    /// The name of month 1 (Baisakh) through 12 (Chaitra). A month outside
    /// 1–12 is returned as its number rather than trapping.
    public static func monthName(_ month: Int, style: MonthNameStyle) -> String {
        let names = monthNames(style: style)
        // Checked against `month`, not `month - 1`: subtracting first
        // overflows for `Int.min`.
        guard (1 ... names.count).contains(month) else { return String(month) }
        return names[month - 1]
    }

    /// The seven weekday names, Sunday through Saturday: Nepali, or English
    /// for the transliterated style.
    public static func weekdayNames(style: MonthNameStyle) -> [String] {
        switch style {
        case .nepali: nepaliWeekdayNames
        case .transliterated: englishWeekdayNames
        }
    }

    /// The name of weekday 1 (Sunday) through 7 (Saturday), or nil outside 1–7.
    public static func weekdayName(_ weekday: Int, style: MonthNameStyle) -> String? {
        guard (1 ... 7).contains(weekday) else { return nil }
        return weekdayNames(style: style)[weekday - 1]
    }

    /// A short weekday name: English names are cut to three letters ("Mon");
    /// Nepali names are already short. Nil outside 1–7.
    public static func shortWeekdayName(_ weekday: Int, style: MonthNameStyle) -> String? {
        guard let name = weekdayName(weekday, style: style) else { return nil }
        switch style {
        case .nepali: return name
        case .transliterated: return String(name.prefix(3))
        }
    }

    /// The date as "day month year", or "day month" without the year:
    /// "11 Ashoj 2083", "११ असोज २०८३".
    public func formatted(_ settings: DisplaySettings, includesYear: Bool = true) -> String {
        let dayAndMonth = "\(settings.digits.format(day)) \(Self.monthName(month, style: settings.monthNames))"
        guard includesYear else { return dayAndMonth }
        return "\(dayAndMonth) \(settings.digits.format(year))"
    }
}

extension GregorianDate {
    /// The twelve English month names, January through December.
    public static let monthNames = gregorianMonthNames

    /// The English name of month 1 (January) through 12 (December). A month
    /// outside 1–12 is returned as its number rather than trapping.
    public static func monthName(_ month: Int) -> String {
        guard (1 ... monthNames.count).contains(month) else { return String(month) }
        return monthNames[month - 1]
    }

    /// The date as "day month year" with an English month name and digits in
    /// `digits`: "27 September 2026", "२७ September २०२६".
    public func formatted(digits: DigitScript) -> String {
        "\(digits.format(day)) \(Self.monthName(month)) \(digits.format(year))"
    }
}

/// Gregorian calendars for clock formatting and today's date, one per time
/// zone. Building a `Calendar` per call dominated formatting cost at clock-tick
/// frequency. Zones are few, so entries never evict. Lock-guarded because
/// callers may be on any thread.
enum ClockCalendars {
    private static let lock = NSLock()
    private nonisolated(unsafe) static var calendars: [String: Calendar] = [:]

    static func gregorian(timeZone: TimeZone) -> Calendar {
        lock.lock()
        defer { lock.unlock() }
        if let cached = calendars[timeZone.identifier] { return cached }
        var calendar = Calendar(identifier: .gregorian)
        // A fixed zone, not the one passed in: an autoupdating zone cached
        // under today's identifier would follow the device to a new zone and
        // answer for it under the old key.
        calendar.timeZone = TimeZone(identifier: timeZone.identifier) ?? timeZone
        calendars[timeZone.identifier] = calendar
        return calendar
    }
}
