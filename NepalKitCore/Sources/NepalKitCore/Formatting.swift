import Foundation

/// Display settings for BS dates, per the locked spec: two independent axes.
public enum DigitScript: String, Sendable, Hashable {
    case latin
    case devanagari
}

public enum MonthNameStyle: String, Sendable, Hashable {
    case nepali
    case transliterated
}

/// The two display axes travel together everywhere dates are shown.
public struct DisplaySettings: Sendable, Hashable {
    public let digits: DigitScript
    public let monthNames: MonthNameStyle

    public init(digits: DigitScript, monthNames: MonthNameStyle) {
        self.digits = digits
        self.monthNames = monthNames
    }
}

/// Canonical transliterated English month names, Baisakh through Chaitra.
public let transliteratedMonthNames = [
    "Baisakh", "Jestha", "Ashar", "Shrawan", "Bhadra", "Ashoj",
    "Kartik", "Mangsir", "Poush", "Magh", "Falgun", "Chaitra",
]

/// Nepali month names, Baisakh through Chaitra.
public let nepaliMonthNames = [
    "बैशाख", "जेठ", "असार", "साउन", "भदौ", "असोज",
    "कात्तिक", "मंसिर", "पुस", "माघ", "फागुन", "चैत",
]

private let devanagariDigits: [Character] = ["०", "१", "२", "३", "४", "५", "६", "७", "८", "९"]

func renderNumber(_ value: Int, digits: DigitScript) -> String {
    switch digits {
    case .latin:
        return String(value)
    case .devanagari:
        return String(value.description.compactMap { $0.wholeNumberValue.map { devanagariDigits[$0] } })
    }
}

/// Formats a plain number (picker year/day) honoring the digit-script setting.
public func formatNumber(_ value: Int, digits: DigitScript) -> String {
    renderNumber(value, digits: digits)
}

func monthName(month: Int, style: MonthNameStyle) -> String {
    switch style {
    case .nepali: return nepaliMonthNames[month - 1]
    case .transliterated: return transliteratedMonthNames[month - 1]
    }
}

/// Nepali weekday names, Sunday through Saturday.
public let nepaliWeekdayNames = [
    "आइत", "सोम", "मंगल", "बुध", "बिही", "शुक्र", "शनि",
]

/// English weekday names, Sunday through Saturday.
public let englishWeekdayNames = [
    "Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday",
]

/// Weekday name for 1 (Sunday) through 7 (Saturday), honoring the month-name
/// setting, or nil outside 1–7.
public func weekdayName(for weekday: Int, style: MonthNameStyle) -> String? {
    guard (1 ... 7).contains(weekday) else { return nil }
    switch style {
    case .nepali: return nepaliWeekdayNames[weekday - 1]
    case .transliterated: return englishWeekdayNames[weekday - 1]
    }
}

/// Formats a Bikram Sambat date as "day month year" honoring both display settings.
public func format(_ bs: BSDay, settings: DisplaySettings) -> String {
    let month = monthName(month: bs.month, style: settings.monthNames)
    return "\(renderNumber(bs.day, digits: settings.digits)) \(month) \(renderNumber(bs.year, digits: settings.digits))"
}

/// Formats a Bikram Sambat date as "day month" for the menu-bar extra, honoring both display settings.
public func formatShort(_ bs: BSDay, settings: DisplaySettings) -> String {
    let month = monthName(month: bs.month, style: settings.monthNames)
    return "\(renderNumber(bs.day, digits: settings.digits)) \(month)"
}

/// Gregorian month names, January through December. The month-name setting
/// governs Bikram Sambat months and weekday names; Gregorian months stay
/// English while digits still honor the digit-script setting.
public let gregorianMonthNames = [
    "January", "February", "March", "April", "May", "June",
    "July", "August", "September", "October", "November", "December",
]

/// Formats a Gregorian date as "day month year", honoring the digit-script setting.
public func formatAD(_ ad: GADay, settings: DisplaySettings) -> String {
    "\(renderNumber(ad.day, digits: settings.digits)) \(gregorianMonthNames[ad.month - 1]) \(renderNumber(ad.year, digits: settings.digits))"
}

private func twoDigits(_ value: Int, digits: DigitScript) -> String {
    let padded = value < 10 ? "0\(value)" : String(value)
    switch digits {
    case .latin:
        return padded
    case .devanagari:
        return String(padded.compactMap { $0.wholeNumberValue.map { devanagariDigits[$0] } })
    }
}

/// Formats a clock time as 24-hour "HH:mm:ss" in the given time zone,
/// honoring the digit-script setting.
public func formatClock(_ date: Date, timeZone: TimeZone, digits: DigitScript) -> String {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = timeZone
    let parts = calendar.dateComponents([.hour, .minute, .second], from: date)
    return "\(twoDigits(parts.hour ?? 0, digits: digits)):\(twoDigits(parts.minute ?? 0, digits: digits)):\(twoDigits(parts.second ?? 0, digits: digits))"
}
