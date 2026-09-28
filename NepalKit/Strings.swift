// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Dibas Sigdel
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
    /// Spoken form of the Devanagari digit option. The shown label deliberately
    /// shows the digits it selects, but those are exactly the characters a voice
    /// may not read, which would leave the option unidentifiable when the two
    /// Settings pickers are read aloud. Same rule as the dates: the screen keeps
    /// the characters, only the announcement is made pronounceable.
    ///
    /// Found by walking the live accessibility tree, not by reading this file.
    static let digitsDevanagariSpoken = "Devanagari 0–9"
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
    static let settingsLabel = "Settings…"
    // Spoken-channel strings. These are *said*, never shown: the visual date
    // always renders as configured, and only the accessibility representation
    // differs (SpokenDate).
    static let appNameForSpeech = "NepalKit"
    /// Introduces the converter's result when spoken. On screen the result is
    /// self-evident next to the pickers that produced it; read aloud it is a
    /// bare date with no way to tell which calendar it is in.
    static let converterResultLabel = "Result"
    static let spokenDateBeyondRange = "date unavailable, calendar data ends 12 April 2028"
    static let aboutLabel = "About NepalKit"
    static let displaySection = "Display"
    static let startupSection = "Startup"
    static let updatesSection = "Software Update"
    static let updateAutomaticallyLabel = "Check automatically"
    static let checkForUpdatesLabel = "Check for Updates…"
    static let updateStatusNotChecked = "Not checked yet"
    static let updateStatusUpToDate = "NepalKit is up to date"
    static let updateStatusUpdateAvailable = "An update is available"
    /// A failed check is not the same answer as an up-to-date one, and saying
    /// so is the whole point: "could not check" must never read as "current".
    static let updateStatusFailed = "Could not check for updates"

    /// About surface. The calendar range is formatted from the dataset's own
    /// bounds, so narrowing or extending the table moves this line with it.
    static func versionLabel(_ version: String) -> String { "Version \(version)" }
    static func datasetVersionLabel(_ version: String) -> String { "Dataset \(version)" }
    static func supportedRange(_ range: ClosedRange<Int>) -> String {
        "\(range.lowerBound)–\(range.upperBound) BS"
    }
    /// Spoken form of the supported range. The shown form uses an en dash,
    /// which is right on screen but which voices read unpredictably — some say
    /// "1975 dash 2084", some pause, some drop it. "to" is unambiguous in every
    /// case. Spoken only; the screen keeps the dash.
    static func supportedRangeSpoken(_ range: ClosedRange<Int>) -> String {
        "\(range.lowerBound) to \(range.upperBound) BS"
    }
    static let calendarDataLabel = "Calendar data"
    static let supportedRangeLabel = "Supported range"
    static let repositoryLabel = "Source repository"
    /// Says what the cross-check established and no more. The table is
    /// corroborated against a second community source, but every shipped year is
    /// still derived from one base table, so this must not read as independent
    /// licensing (ADR-0010).
    static let calendarDataAttribution = """
        Month lengths follow the officially published Nepali Patro and are \
        cross-checked month-by-month against community tables. The table is \
        derived from those sources across its whole range.
        """
}
