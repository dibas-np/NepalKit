// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Dibas Sigdel
import Foundation
import NepalKitCore

/// Persists the two display axes in UserDefaults. The store stays
/// dumb and injectable so persistence is testable without the app running.
///
/// `nonisolated` because the Siri intents read it from `perform()`, which
/// runs off the main actor (ticket 03's mechanic: no UI launch, no actor
/// hop). UserDefaults operations are thread-safe, and every member is a
/// trivial value read or write, so nothing here needs an actor.
nonisolated struct SettingsStore {
    static let digitScriptKey = "digitScript"
    static let monthNameStyleKey = "monthNameStyle"

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
}
