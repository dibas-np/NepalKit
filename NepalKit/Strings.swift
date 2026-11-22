// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Dibas Sigdel
import NepalKitCore

nonisolated enum Strings {
    static let bsDateUnavailable = "Bikram Sambat date unavailable"
    static let weekdaySeparator = "·"
    static func datedWithWeekday(_ date: String, _ weekday: String) -> String {
        "\(date) \(weekdaySeparator) \(weekday)"
    }
    static func supportedThrough(_ bsYear: Int, digits: DigitScript) -> String {
        "Supported through \(digits.format(bsYear)) BS"
    }
    static let menuBarBeyondRange = "n/a"
    static let menuBarUpdateMarker = "! "
    static let updateAvailableSpoken = "update available"
    static let digitScriptLabel = "Digits"
    static let digitsLatin = "Latin 0–9"
    static let digitsLatinSpoken = "Latin 0-9"
    static let digitsDevanagari = "Devanagari ०–९"
    static let digitsDevanagariSpoken = "Devanagari 0-9"
    static let monthNameLabel = "Month names"
    static let monthsNepali = "Nepali"
    static let monthsTransliterated = "Transliterated"
    static let displayPreviewLabel = "Preview"
    static let nepalTimeLabel = "Nepal Time"
    static let localTimeLabel = "Local"
    static let todayLabel = "Today"
    static let launchAtLoginLabel = "Launch at login"
    static let loginItemNeedsApproval = "NepalKit will not open at login until you allow it in System Settings, under Login Items."
    static let openLoginItemsSettings = "Open Login Items Settings"
    static let converterLabel = "Converter"
    static let converterDirectionLabel = "Direction"
    static let popoverDestinationsLabel = "Destination"
    static let appName = "NepalKit"
    static let bsToAD = "BS → AD"
    static let adToBS = "AD → BS"
    static let bsToADSpoken = "Bikram Sambat to Gregorian"
    static let adToBSSpoken = "Gregorian to Bikram Sambat"
    static let yearLabel = "Year"
    static let monthLabel = "Month"
    static let dayLabel = "Day"
    static let converterOutOfRange = "Outside supported range"
    static let converterProvisionalNote = "Provisional projection, not yet in the official Nepali Patro"
    static let previousMonthLabel = "Previous Month"
    static let nextMonthLabel = "Next Month"
    static let showTodayHelp = "Shows the month containing today"
    static let monthGridDaysLabel = "Days"
    static let tomorrowLabel = "Tomorrow"
    static let yesterdayLabel = "Yesterday"
    static func relativeDays(_ days: Int, digits: DigitScript) -> String {
        switch days {
        case 0: todayLabel
        case 1: tomorrowLabel
        case -1: yesterdayLabel
        case 2...: "In \(digits.format(days)) days"
        default: "\(digits.format(-days)) days ago"
        }
    }
    static let copyDateLabel = "Copy"
    static let copyDateHelp = "Copies the Bikram Sambat date"
    static let closeDayDetailsLabel = "Close Day Details"
    static let monthGridDayHelp = "Shows this day's details"
    static func festivalNames(_ names: [String]) -> String { names.joined(separator: ", ") }
    static func monthGridPastRange(_ bsYear: Int, digits: DigitScript) -> String {
        "Today is past the supported range. \(supportedThrough(bsYear, digits: digits))."
    }
    static let quitLabel = "Quit NepalKit"
    static let quitFooterLabel = "Quit"
    static let settingsHelp = "Opens the Settings window"
    static let quitHelp = "Quits NepalKit"
    static let settingsLabel = "Settings…"
    static let settingsLabelSpoken = "Settings"

    static let updateButtonLabel = "Update…"
    static let updateButtonLabelSpoken = "Update"
    static let updateButtonHelp = "Shows the available update and its install options"
    static let appNameForSpeech = "NepalKit"
    static let converterResultLabel = "Result"
    static func spokenDateBeyondRange(_ gregorianEnd: String) -> String {
        "date unavailable, calendar data ends \(gregorianEnd)"
    }
    static let menuBarTabTitle = "Menu Bar"
    static let generalTabTitle = "General"
    static let aboutTabTitle = "About"
    static let aboutCurrentBuild = "This build"
    static let menuBarPreviewCaption = "The menu bar shows"
    static let displaySection = "Display"
    static let startupSection = "Startup"

    static let siriShortcutsSection = "Siri & Shortcuts"
    static let siriShortcutsSummary = "Ask Siri for today's, tomorrow's or yesterday's Nepali date; run the conversions from Shortcuts."
    static let siriTodayCapability = "Today's date in Bikram Sambat"
    static let siriTomorrowCapability = "Tomorrow's date in Bikram Sambat"
    static let siriYesterdayCapability = "Yesterday's date in Bikram Sambat"
    static let siriConvertToBSCapability = "Convert a Gregorian date to Bikram Sambat"
    static let siriConvertToGregorianCapability = "Convert a Bikram Sambat date to Gregorian"

    struct Capability: Identifiable {
        let title: String
        let phrase: String
        var spokenDescription: String { "\(title). \(phrase)" }
        var id: String { phrase }
    }

    static var siriShortcutCapabilities: [Capability] {
        [
            Capability(title: siriTodayCapability, phrase: siriTodayPhrase),
            Capability(title: siriTomorrowCapability, phrase: siriTomorrowPhrase),
            Capability(title: siriYesterdayCapability, phrase: siriYesterdayPhrase),
        Capability(title: siriConvertToBSCapability, phrase: siriConvertToBSPhrase),
            Capability(title: siriConvertToGregorianCapability, phrase: siriConvertToGregorianPhrase),
        ]
    }

    static let siriTodayPhrase = "What is today's Nepali date with \(appName)"
    static let siriTomorrowPhrase = "What is tomorrow's Nepali date with \(appName)"
    static let siriYesterdayPhrase = "What was yesterday's Nepali date with \(appName)"
    static let siriConvertToBSPhrase = "Convert a date to Bikram Sambat with \(appName)"
    static let siriConvertToGregorianPhrase = "Convert a Bikram Sambat date to Gregorian with \(appName)"
    static let updatesSection = "Software Update"
    static let updateAutomaticallyLabel = "Check automatically"
    static let checkForUpdatesLabel = "Check for Updates…"
    static let checkForUpdatesLabelSpoken = "Check for Updates"
    static let updateStatusNotChecked = "Not checked yet"
    static let updateStatusUpToDate = "NepalKit is up to date"
    static let updateStatusUpdateAvailable = "An update is available"
    static let updateStatusFailed = "Could not check for updates"

    static func updateStatusFailedReason(_ reason: String) -> String {
        "\(updateStatusFailed). The updater reported: “\(reason)”"
    }

    static func updateLastChecked(_ date: String) -> String {
        "Last checked: \(date)"
    }

    static let updateCheckSkippedTransientLaunch = "Skipped: this build cannot update itself in place"

    static let loginItemFailed = "Could not change launch at login"

    static func loginItemFailureReason(_ failure: LoginItemFailure) -> String {
        switch failure {
        case .registration(let reason):
            "\(loginItemFailed) (turning it on). The system reported: “\(reason)”"
        case .deregistration(let reason):
            "\(loginItemFailed) (turning it off). The system reported: “\(reason)”"
        }
    }

    static func versionLabel(_ version: String) -> String { "Version \(version)" }
    static func supportedRange(_ range: ClosedRange<Int>) -> String {
        "\(range.lowerBound)–\(range.upperBound) BS"
    }
    static func supportedRangeSpoken(_ range: ClosedRange<Int>) -> String {
        "\(range.lowerBound) to \(range.upperBound) BS"
    }
    static func provisionalYearsNote(_ years: Set<Int>) -> String? {
        guard !years.isEmpty else { return nil }
        let sorted = years.sorted().map(String.init)
        let list = sorted.count == 1 ? sorted[0] : "\(sorted.dropLast().joined(separator: ", ")) and \(sorted[sorted.count - 1])"
        return years.count == 1
            ? "\(list) BS is a provisional projection until the official Nepali Patro is published."
            : "\(list) BS are provisional projections until the official Nepali Patro is published."
    }
    static let datasetVersionLabel = "Dataset version"
    static let supportedRangeLabel = "Supported range"
    static let repositoryLabel = "Source repository"
    static let sourceLinkTitle = "Source"
}
