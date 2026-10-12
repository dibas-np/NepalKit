// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Dibas Sigdel
import Foundation
import NepalKitCore

/// Persists the two display axes, the time reference and the menu-bar format in
/// UserDefaults. The store stays dumb and injectable so persistence is testable
/// without the app running.
///
/// `nonisolated` because the Siri intents read it from `perform()`, which
/// runs off the main actor (ticket 03's mechanic: no UI launch, no actor
/// hop). UserDefaults operations are thread-safe, and every member is a
/// trivial value read or write, so nothing here needs an actor.
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

    /// - Parameter defaults: must stay `.standard` in production, which resolves
    ///   to the app's own preference domain keyed by bundle identifier. A
    ///   versioned suite name, a build-numbered key, or a custom container would
    ///   each survive an in-place update and silently reset every user's settings
    ///   on upgrade, which is invisible from the outside. The injection point
    ///   exists for tests, which pass a throwaway suite.
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

    /// Nepal Time when nothing is stored, or something this version does not
    /// know, so every existing user keeps the behaviour they had (ADR-0017).
    var timeReference: TimeReference {
        TimeReference(rawValue: defaults.string(forKey: Self.timeReferenceKey) ?? "") ?? .nepal
    }

    func save(_ reference: TimeReference) {
        defaults.set(reference.rawValue, forKey: Self.timeReferenceKey)
    }

    /// One Boolean key per option rather than an encoded blob, so a later
    /// option cannot make an older stored value undecodable. A missing key reads
    /// as `false`, every option's default, giving `.standard`.
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
