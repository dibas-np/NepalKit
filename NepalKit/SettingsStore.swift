// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Dibas Sigdel
import Foundation
import NepalKitCore

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

    var timeReference: TimeReference {
        TimeReference(rawValue: defaults.string(forKey: Self.timeReferenceKey) ?? "") ?? .nepal
    }

    func save(_ reference: TimeReference) {
        defaults.set(reference.rawValue, forKey: Self.timeReferenceKey)
    }

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
