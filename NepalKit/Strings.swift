// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Dibas Sigdel
import NepalKitCore

/// User-facing strings in one place. Not a localization system: the app ships
/// one UI language (the month-name language setting is a date-presentation
/// setting, not a second UI language).
nonisolated enum Strings {
    static let bsDateUnavailable = "Bikram Sambat date unavailable"
    /// Separator between a date and its weekday on a shown date line.
    ///
    /// Shared by both places the pairing appears — the popover's Gregorian
    /// line, which lays the two halves out as separate `Text`s in an `HStack`
    /// so they wrap independently, and the converter's shown result, which
    /// composes them through `datedWithWeekday`. The popover therefore does not
    /// call the composer; what must not drift is the separator itself, because
    /// the spoken channel has to avoid it in both.
    static let weekdaySeparator = "·"
    static func datedWithWeekday(_ date: String, _ weekday: String) -> String {
        "\(date) \(weekdaySeparator) \(weekday)"
    }
    /// Honors the digit-script setting like every other number the app renders.
    static func supportedThrough(_ bsYear: Int, digits: DigitScript) -> String {
        "Supported through \(formatNumber(bsYear, digits: digits)) BS"
    }
    /// Compact menu-bar marker for the range boundary. The popover states the
    /// boundary in words; the menu bar only has room to avoid looking broken.
    static let menuBarBeyondRange = "n/a"
    /// Prefix on the menu-bar date while a scheduled update is still awaiting
    /// the user's attention. A scheduled check is run by a windowless app, so
    /// its alert is easy to never see; the menu bar is the one surface this user
    /// actually looks at. Carries its own trailing space, so the prefix stays
    /// one unit rather than a glyph and a separator at the call site.
    static let menuBarUpdateMarker = "! "
    /// Spoken form of the same reminder. Said in words rather than read as the
    /// glyph, for the same reason the date is spoken and not spelled out: a
    /// voice cannot read "!", and this is the one thing on the menu bar that
    /// changes what the user should do. A clause rather than a sentence, since
    /// `SpokenDate.menuBar` composes it between the app name and the date.
    static let updateAvailableSpoken = "update available"
    static let digitScriptLabel = "Digits"
    static let digitsLatin = "Latin 0–9"
    /// Spoken form of the Latin digit option. The shown label keeps its en dash
    /// for the same reason `digitsDevanagariSpoken` keeps its Devanagari digits:
    /// on screen the label is describing the range it selects, and only the
    /// announcement is made pronounceable.
    static let digitsLatinSpoken = "Latin 0-9"
    static let digitsDevanagari = "Devanagari ०–९"
    /// Spoken form of the Devanagari digit option. The shown label deliberately
    /// shows the digits it selects, but those are exactly the characters a voice
    /// may not read, which would leave the option unidentifiable when the two
    /// Settings pickers are read aloud. Same rule as the dates: the screen keeps
    /// the characters, only the announcement is made pronounceable.
    ///
    /// The separator is a plain hyphen for the reason `supportedRangeSpoken`
    /// spells its dash out: an en dash is unpredictable aloud — some voices say
    /// "0 dash 9", some pause, some drop it. This string exists only to be
    /// spoken, so unlike `digitsLatin` there is no shown counterpart whose
    /// punctuation it has to keep.
    static let digitsDevanagariSpoken = "Devanagari 0-9"
    static let monthNameLabel = "Month names"
    static let monthsNepali = "Nepali"
    static let monthsTransliterated = "Transliterated"
    static let nepalTimeLabel = "Nepal Time"
    static let localTimeLabel = "Local"
    static let todayLabel = "Today"
    static let launchAtLoginLabel = "Launch at login"
    static let converterLabel = "Converter"
    /// Names the direction toggle. Distinguishes it from the popover's own
    /// Today/Converter switcher, which is a different control directly above.
    static let converterDirectionLabel = "Direction"
    /// Names the pair of destinations the popover's segmented control switches
    /// between. The two segments are read out as bare words otherwise, which
    /// does not convey that they are a choice between views.
    static let popoverDestinationsLabel = "Destination"
    /// The app's own name, for the popover header. Spoken-channel safe: this is
    /// visible, and the name is what a screen-reader user needs to confirm which
    /// app the popover belongs to, since a menu-bar extra has no Dock icon or
    /// window title to carry it.
    static let appName = "NepalKit"
    /// Shown on the direction toggle's segments, so abbreviated: the two full
    /// calendar names do not fit a segmented control inside a 340pt popover and
    /// the framework clips rather than wraps. "Bikram Sambat → Gregorian"
    /// rendered as "ikram Sambat → Gregorian".
    ///
    /// The abbreviations are spoken in full - see `bsToADSpoken` - because
    /// "BS" and "AD" are not self-evident aloud, and this is the control that
    /// says which calendar the result will be in.
    static let bsToAD = "BS → AD"
    static let adToBS = "AD → BS"
    /// Spoken form of the direction segments, which the abbreviations are not
    /// enough to convey. Read aloud, "BS to AD" gives no clue what either
    /// letter stands for, and the result line it governs is the whole point of
    /// the tab.
    static let bsToADSpoken = "Bikram Sambat to Gregorian"
    static let adToBSSpoken = "Gregorian to Bikram Sambat"
    static let yearLabel = "Year"
    static let monthLabel = "Month"
    static let dayLabel = "Day"
    static let converterOutOfRange = "Outside supported range"
    static let quitLabel = "Quit NepalKit"
    /// Spoken purposes for the footer's icon-only buttons. A symbol with no
    /// accessible name is the worst case in the whole app: a screen-reader user
    /// hears "button" three times and cannot tell the actions apart, while a
    /// sighted user sees three distinct glyphs and reads them instantly.
    static let settingsHelp = "Opens the Settings window"
    static let aboutHelp = "Opens the About window"
    static let quitHelp = "Quits NepalKit"
    static let settingsLabel = "Settings…"
    /// Spoken form: the ellipsis is a visual affordance marking an action that
    /// continues past the footer, and there is nothing to add by saying it —
    /// "Settings" is the whole action.
    static let settingsLabelSpoken = "Settings"
    // Spoken-channel strings. These are *said*, never shown: the visual date
    // always renders as configured, and only the accessibility representation
    // differs (SpokenDate).
    static let appNameForSpeech = "NepalKit"
    /// Introduces the converter's result when spoken. On screen the result is
    /// self-evident next to the pickers that produced it; read aloud it is a
    /// bare date with no way to tell which calendar it is in.
    static let converterResultLabel = "Result"
    /// Spoken form of the range boundary. The Gregorian end date is passed in
    /// rather than spelled here: it is derived from the dataset (ADR-0010), so
    /// no literal in this file can drift from the shipped table.
    static func spokenDateBeyondRange(_ gregorianEnd: String) -> String {
        "date unavailable, calendar data ends \(gregorianEnd)"
    }
    static let aboutLabel = "About NepalKit"
    static let displaySection = "Display"
    static let startupSection = "Startup"
    static let updatesSection = "Software Update"
    static let updateAutomaticallyLabel = "Check automatically"
    static let checkForUpdatesLabel = "Check for Updates…"
    /// Spoken form: the ellipsis is a visual affordance, not a spoken one. Shown,
    /// it marks a control that opens a sheet elsewhere; aloud it buys a pause and
    /// no meaning.
    static let checkForUpdatesLabelSpoken = "Check for Updates"
    static let updateStatusNotChecked = "Not checked yet"
    static let updateStatusUpToDate = "NepalKit is up to date"
    static let updateStatusUpdateAvailable = "An update is available"
    /// A failed check is not the same answer as an up-to-date one, and saying
    /// so is the whole point: "could not check" must never read as "current".
    static let updateStatusFailed = "Could not check for updates"

    /// The reason is the framework's own description of what went wrong.
    /// Shown, not swallowed: "could not check" without a why is undebuggable,
    /// both for the user reporting it and for the maintainer reading the report.
    ///
    /// The reason is presented as a quoted detail rather than spliced into the
    /// sentence. An updater framework phrases its errors for its own user
    /// interface, and those phrases are not always about the check: this build
    /// reported `Could not check for updates: You're up to date!`, which asserts
    /// two contradictory things at once and is worse than either alone. Quoting
    /// keeps the two claims separable, and the quotes make it obvious the
    /// contradiction came from the framework rather than from this app.
    static func updateStatusFailedReason(_ reason: String) -> String {
        "\(updateStatusFailed). The updater reported: “\(reason)”"
    }

    /// Refused rather than failed: the check was declined before it ran, because
    /// this build could not have acted on any answer. Said rather than silent,
    /// because a user who asked to check and got nothing back cannot tell that
    /// apart from a network problem.
    ///
    /// Ours rather than the framework's — the reason beside it is the one the
    /// updater phrases for itself and this file only passes along, and this is
    /// the single sentence the app raises itself. So it lives here with the rest
    /// instead of as a literal at the throw site.
    ///
    /// One line with its literal on purpose: `SpokenDateTests` parses this file
    /// to sweep the spoken channel, and a declaration it cannot read a value out
    /// of fails that test rather than going unchecked.
    static let updateCheckSkippedTransientLaunch = "Skipped: this build cannot update itself in place"

    /// A refused register/unregister is invisible on the toggle: `isOn` follows
    /// the system, so the toggle springs back without ever saying why. This
    /// sentence is where the reason lands.
    ///
    /// Parenthetical rather than a second clause, so the direction of the change
    /// is readable while the toggle is still mid-rebound — "turning it on" beside
    /// a control that just sprang back to off is the whole ambiguity.
    static let loginItemFailed = "Could not change launch at login"

    /// The system reports an opaque Cocoa error, so the sentence around it is
    /// the app's and the payload is quoted rather than spliced in, for the same
    /// reason as `updateStatusFailedReason`: the system's phrasing is written
    /// for the login-item machinery, not for this sentence, and quoting keeps
    /// the two claims separable if it turns out to contradict ours.
    static func loginItemFailureReason(_ failure: LoginItemFailure) -> String {
        switch failure {
        case .registration(let reason):
            "\(loginItemFailed) (turning it on). The system reported: “\(reason)”"
        case .deregistration(let reason):
            "\(loginItemFailed) (turning it off). The system reported: “\(reason)”"
        }
    }

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
    static let licenseLabel = "Licence"
    /// The GPL covers the app code only. The bundled calendar table carries no
    /// licence from this project at all — a note implying it is "licensed
    /// separately" would claim a licence exists, which is the overclaim
    /// SOURCES.md exists to prevent (ADR-0010).
    static let licenseScopeNote =
        "Applies to the app code. The bundled calendar data carries no licence from this project; see SOURCES.md in the repository."
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
