// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Dibas Sigdel
import NepalKitCore

/// User-facing strings. The app ships one UI language; this is not a localization system.
nonisolated enum Strings {
    static let bsDateUnavailable = "Bikram Sambat date unavailable"
    /// Separator between a date and its weekday. The spoken channel must avoid it.
    static let weekdaySeparator = "·"
    static func datedWithWeekday(_ date: String, _ weekday: String) -> String {
        "\(date) \(weekdaySeparator) \(weekday)"
    }
    static func supportedThrough(_ bsYear: Int, digits: DigitScript) -> String {
        "Supported through \(digits.format(bsYear)) BS"
    }
    static let menuBarBeyondRange = "n/a"
    /// Prefix on the menu-bar date while a scheduled update awaits attention.
    /// Carries its own trailing space.
    static let menuBarUpdateMarker = "! "
    static let updateAvailableSpoken = "update available"
    static let digitScriptLabel = "Digits"
    static let digitsLatin = "Latin 0–9"
    static let digitsLatinSpoken = "Latin 0-9"
    static let digitsDevanagari = "Devanagari ०–९"
    /// Spoken form of the Devanagari option: a voice may not read the digits,
    /// and an en dash is read unpredictably.
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
    /// Abbreviated to fit the segmented control; spoken in full via `bsToADSpoken`.
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
    static let monthGridDaysLabel = "Days" // names the weekday header and the grid for VoiceOver
    static let tomorrowLabel = "Tomorrow"
    static let yesterdayLabel = "Yesterday"
    /// The count honours the digit setting on screen; the spoken channel passes `.latin`.
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
    static let closeDayDetailsLabel = "Close Day Details" // the details card under the grid
    static let monthGridDayHelp = "Shows this day's details" // a grid day is a button that shows them
    static func festivalNames(_ names: [String]) -> String { names.joined(separator: ", ") }
    static func monthGridPastRange(_ bsYear: Int, digits: DigitScript) -> String {
        "Today is past the supported range. \(supportedThrough(bsYear, digits: digits))."
    }
    static let quitLabel = "Quit NepalKit"
    static let quitFooterLabel = "Quit"
    /// Help strings for the footer buttons. The Settings button is a bare glyph,
    /// so these are its only accessible description.
    static let settingsHelp = "Opens the Settings window"
    static let quitHelp = "Quits NepalKit"
    /// The footer draws only the glyph; this is the announced name.
    static let settingsLabel = "Settings…"
    static let settingsLabelSpoken = "Settings"

    /// The footer's update button, shown only once a check has found an update.
    static let updateButtonLabel = "Update…"
    static let updateButtonLabelSpoken = "Update"
    /// Not "installs the update": the install happens in the updater's own alert.
    static let updateButtonHelp = "Shows the available update and its install options"
    // Spoken-channel strings: said, never shown (see `SpokenDate`).
    static let appNameForSpeech = "NepalKit"
    static let converterResultLabel = "Result"
    /// The Gregorian end date is derived from the dataset, not spelled here.
    static func spokenDateBeyondRange(_ gregorianEnd: String) -> String {
        "date unavailable, calendar data ends \(gregorianEnd)"
    }
    // MARK: - Settings window
    static let menuBarTabTitle = "Menu Bar"
    static let generalTabTitle = "General"
    static let aboutTabTitle = "About"
    /// Stands in for the build's provenance on the About tab's version row. The
    /// row names the version; this says that is the version you are running, as
    /// opposed to a version some other build reports.
    static let aboutCurrentBuild = "This build"
    /// What the Menu Bar tab shows: the literal menu-bar text. The caption names
    /// where the value is actually rendered, because a date in a preferences
    /// window is otherwise indistinguishable from a setting.
    static let menuBarPreviewCaption = "The menu bar shows"
    static let displaySection = "Display"
    static let startupSection = "Startup"

    // MARK: - Siri & Shortcuts

    // One line per declaration: `SpokenDateTests` parses this file and fails on
    // any `static let` whose value it cannot read off the line.
    static let siriShortcutsSection = "Siri & Shortcuts"
    static let siriShortcutsSummary = "Ask Siri for today's, tomorrow's or yesterday's Nepali date; run the conversions from Shortcuts."
    static let siriTodayCapability = "Today's date in Bikram Sambat"
    static let siriTomorrowCapability = "Tomorrow's date in Bikram Sambat"
    static let siriYesterdayCapability = "Yesterday's date in Bikram Sambat"
    static let siriConvertToBSCapability = "Convert a Gregorian date to Bikram Sambat"
    static let siriConvertToGregorianCapability = "Convert a Bikram Sambat date to Gregorian"

    /// One capability and the phrase that invokes it.
    struct Capability: Identifiable {
        let title: String
        /// The registered phrase with `\(.applicationName)` written out.
        let phrase: String
        var spokenDescription: String { "\(title). \(phrase)" }
        var id: String { phrase }
    }

    /// The capabilities this build registers, in Settings order. Computed so
    /// the `SpokenDateTests` sweep sees no unreadable stored constant.
    static var siriShortcutCapabilities: [Capability] {
        [
            Capability(title: siriTodayCapability, phrase: siriTodayPhrase),
            Capability(title: siriTomorrowCapability, phrase: siriTomorrowPhrase),
            Capability(title: siriYesterdayCapability, phrase: siriYesterdayPhrase),
        Capability(title: siriConvertToBSCapability, phrase: siriConvertToBSPhrase),
            Capability(title: siriConvertToGregorianCapability, phrase: siriConvertToGregorianPhrase),
        ]
    }

    /// Phrase templates as registered, with the application-name token spelled out.
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
    /// Must never read as "up to date".
    static let updateStatusFailed = "Could not check for updates"

    /// Quotes the updater's own reason so it stays separable from the app's wording.
    static func updateStatusFailedReason(_ reason: String) -> String {
        "\(updateStatusFailed). The updater reported: “\(reason)”"
    }

    /// The date is formatted by the caller in the user's locale and calendar.
    static func updateLastChecked(_ date: String) -> String {
        "Last checked: \(date)"
    }

    /// The check was declined because this build cannot update itself in place.
    static let updateCheckSkippedTransientLaunch = "Skipped: this build cannot update itself in place"

    /// Shown because a refused register/unregister just springs the toggle back.
    static let loginItemFailed = "Could not change launch at login"

    /// Quotes the system's reason, as `updateStatusFailedReason` does.
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
    /// Says "to" instead of the en dash, which voices read unpredictably.
    static func supportedRangeSpoken(_ range: ClosedRange<Int>) -> String {
        "\(range.lowerBound) to \(range.upperBound) BS"
    }
    /// Generated from the dataset's provisional years; nil when every row is attested.
    static func provisionalYearsNote(_ years: Set<Int>) -> String? {
        guard !years.isEmpty else { return nil }
        // Joined by hand: this file does not import Foundation.
        let sorted = years.sorted().map(String.init)
        let list = sorted.count == 1 ? sorted[0] : "\(sorted.dropLast().joined(separator: ", ")) and \(sorted[sorted.count - 1])"
        return years.count == 1
            ? "\(list) BS is a provisional projection until the official Nepali Patro is published."
            : "\(list) BS are provisional projections until the official Nepali Patro is published."
    }
    static let datasetVersionLabel = "Dataset version"
    static let supportedRangeLabel = "Supported range"
    static let repositoryLabel = "Source repository"
    /// Short for the narrow sidebar row; `repositoryLabel` is what gets announced.
    static let sourceLinkTitle = "Source"
}
