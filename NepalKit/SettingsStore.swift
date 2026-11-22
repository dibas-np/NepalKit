// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Dibas Sigdel
import Foundation
import NepalKitCore

/// Persists display settings, the time reference and the menu-bar format in
/// UserDefaults. `nonisolated` because the Siri intents read it off the main actor.
nonisolated struct SettingsStore {
    static let digitScriptKey = "digitScript"
    static let monthNameStyleKey = "monthNameStyle"
    static let menuBarShowsWeekdayKey = "menuBarShowsWeekday"
    static let menuBarShowsYearKey = "menuBarShowsYear"
    static let menuBarShowsTimeKey = "menuBarShowsTime"
    static let menuBarUsesTwentyFourHourClockKey = "menuBarUsesTwentyFourHourClock"
    static let menuBarShowsSecondsKey = "menuBarShowsSeconds"
    static let timeReferenceKey = "timeReference"

    private let defaults: UserDefaults

    /// - Parameter defaults: `.standard` in production. A versioned suite or key
    ///   would silently reset every user's settings on upgrade.
    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var settings: DisplaySettings {
        let digits = DigitScript(rawValue: defaults.string(forKey: Self.digitScriptKey) ?? "") ?? .latin
        let monthNames = MonthNameStyle(rawValue: defaults.string(forKey: Self.monthNameStyleKey) ?? "") ?? .transliterated
        return DisplaySettings(digits: digits, monthNames: monthNames)
    }

    func save(_ settings: DisplaySettings) {
        defaults.set(settings.digits.rawValue, forKey: Self.digitScriptKey)
        defaults.set(settings.monthNames.rawValue, forKey: Self.monthNameStyleKey)
    }

    /// Nepal Time when nothing (or an unknown value) is stored (ADR-0017).
    var timeReference: TimeReference {
        TimeReference(rawValue: defaults.string(forKey: Self.timeReferenceKey) ?? "") ?? .nepal
    }

    func save(_ reference: TimeReference) {
        defaults.set(reference.rawValue, forKey: Self.timeReferenceKey)
    }

    /// One Boolean key per option, so a new option never breaks an older stored value.
    var menuBarFormat: MenuBarFormat {
        MenuBarFormat(
            showsWeekday: defaults.bool(forKey: Self.menuBarShowsWeekdayKey),
            showsYear: defaults.bool(forKey: Self.menuBarShowsYearKey),
            showsTime: defaults.bool(forKey: Self.menuBarShowsTimeKey),
            usesTwentyFourHourClock: defaults.bool(forKey: Self.menuBarUsesTwentyFourHourClockKey),
            showsSeconds: defaults.bool(forKey: Self.menuBarShowsSecondsKey)
        )
    }

    func save(_ format: MenuBarFormat) {
        defaults.set(format.showsWeekday, forKey: Self.menuBarShowsWeekdayKey)
        defaults.set(format.showsYear, forKey: Self.menuBarShowsYearKey)
        defaults.set(format.showsTime, forKey: Self.menuBarShowsTimeKey)
        defaults.set(format.usesTwentyFourHourClock, forKey: Self.menuBarUsesTwentyFourHourClockKey)
        defaults.set(format.showsSeconds, forKey: Self.menuBarShowsSecondsKey)
    }
}
