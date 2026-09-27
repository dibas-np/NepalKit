/// Display settings for BS dates, per the locked spec: two independent axes.
public enum DigitScript: String, Sendable {
    case latin
    case devanagari
}

public enum MonthNameStyle: String, Sendable {
    case nepali
    case transliterated
}

/// The two display axes travel together everywhere dates are shown.
public struct DisplaySettings: Sendable {
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

func monthName(month: Int, style: MonthNameStyle) -> String {
    switch style {
    case .nepali: nepaliMonthNames[month - 1]
    case .transliterated: transliteratedMonthNames[month - 1]
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
