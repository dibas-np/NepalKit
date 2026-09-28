// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Dibas Sigdel
import Observation
import NepalKitCore

/// Observable display settings: persisted through SettingsStore, published
/// so the menu-bar extra and popover refresh instantly on change.
@MainActor
@Observable
final class DisplaySettingsModel {
    private(set) var settings: DisplaySettings

    private let store: SettingsStore

    /// `store` is optional rather than defaulted to `SettingsStore()` in the
    /// signature. A default argument is evaluated in a nonisolated context even
    /// when the initialiser is `@MainActor`, so the compiler cannot prove the
    /// main-actor-isolated `SettingsStore` initialiser is safe there. Optional
    /// plus a default built in the body says the same thing and type-checks.
    init(store: SettingsStore? = nil) {
        let store = store ?? SettingsStore()
        self.store = store
        self.settings = store.settings
    }

    func save(_ settings: DisplaySettings) {
        store.save(settings)
        self.settings = settings
    }

    func save(digits: DigitScript) {
        save(DisplaySettings(digits: digits, monthNames: settings.monthNames))
    }

    func save(monthNames: MonthNameStyle) {
        save(DisplaySettings(digits: settings.digits, monthNames: monthNames))
    }

    /// Binding targets for the Settings pickers: writing runs the same save
    /// path as `save(_:)`, so persistence and every reader move together.
    var digits: DigitScript {
        get { settings.digits }
        set { save(digits: newValue) }
    }

    var monthNames: MonthNameStyle {
        get { settings.monthNames }
        set { save(monthNames: newValue) }
    }
}
