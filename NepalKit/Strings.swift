import NepalKitCore

/// User-facing strings in one place. Not a localization system: the app ships
/// one UI language (the month-name language setting is a date-presentation
/// setting, not a second UI language).
enum Strings {
    static let dateUnavailable = "Date unavailable"
    static let bsDateUnavailable = "Bikram Sambat date unavailable"
    /// Honors the digit-script setting like every other number the app renders.
    static func supportedThrough(_ bsYear: Int, digits: DigitScript) -> String {
        "Supported through \(formatNumber(bsYear, digits: digits)) BS"
    }
    /// Compact menu-bar marker for the range boundary. The popover states the
    /// boundary in words; the menu bar only has room to avoid looking broken.
    static let menuBarBeyondRange = "n/a"
    static let digitScriptLabel = "Digits"
    static let digitsLatin = "Latin 0–9"
    static let digitsDevanagari = "Devanagari ०–९"
    static let monthNameLabel = "Month names"
    static let monthsNepali = "Nepali"
    static let monthsTransliterated = "Transliterated"
    static let nepalTimeLabel = "Nepal Time"
    static let localTimeLabel = "Local"
    static let todayLabel = "Today"
    static let launchAtLoginLabel = "Launch at login"
    static let converterLabel = "Converter"
    static let bsToAD = "Bikram Sambat → Gregorian"
    static let adToBS = "Gregorian → Bikram Sambat"
    static let yearLabel = "Year"
    static let monthLabel = "Month"
    static let dayLabel = "Day"
    static let converterOutOfRange = "Outside supported range"
    static let quitLabel = "Quit NepalKit"
}
