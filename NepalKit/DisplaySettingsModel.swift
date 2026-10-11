// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Dibas Sigdel
import Foundation
import Observation
import NepalKitCore

/// Observable display settings: persisted through SettingsStore, published
/// so the menu-bar extra and popover refresh instantly on change.
@MainActor
@Observable
final class DisplaySettingsModel {
    private(set) var settings: DisplaySettings
    /// Whether today follows Nepal Time or the Mac's own zone (ADR-0017).
    private(set) var timeReference: TimeReference

    private let store: SettingsStore
    /// What else must move when the time reference does. The menu-bar clock,
    /// the popover's clock and the month grid each hold the zone they schedule
    /// against, and a timer armed for Nepal's midnight is wrong the moment the
    /// user picks their own zone, so they are told rather than left to notice
    /// at their next tick. Not observed: it never draws.
    @ObservationIgnored private var timeReferenceObservers: [@MainActor (TimeReference) -> Void] = []

    /// `store` is optional rather than defaulted to `SettingsStore()` in the
    /// signature. A default argument is evaluated in a nonisolated context,
    /// so a default that constructs a main-actor-isolated type is fragile
    /// under strict isolation checking even when the initialiser itself is
    /// `@MainActor` — whether it warns varies by toolchain and language mode.
    /// Building the default in the body is correct under every setting, and
    /// matches `WindowPresentation` and `LoginItemModel`. Tests still inject
    /// a store explicitly.
    init(store: SettingsStore? = nil) {
        let store = store ?? SettingsStore()
        self.store = store
        self.settings = store.settings
        self.timeReference = store.timeReference
    }

    /// The zone "today" is read in: Nepal Time, or the Mac's own.
    var timeZone: TimeZone { timeReference.timeZone }

    /// Persists the time reference and tells every observer, in the same call,
    /// so the menu bar, the popover and the timers change together.
    func save(_ reference: TimeReference) {
        store.save(reference)
        timeReference = reference
        for observer in timeReferenceObservers {
            observer(reference)
        }
    }

    /// Registers a model that must follow the time reference. Called by the app
    /// scene, which is the one place that holds every model.
    func observeTimeReference(_ observer: @escaping @MainActor (TimeReference) -> Void) {
        timeReferenceObservers.append(observer)
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

    var timeReferenceSelection: TimeReference {
        get { timeReference }
        set { save(newValue) }
    }

    #if DEBUG
    /// A model over a throwaway preferences domain, seeded to the non-default
    /// pair.
    ///
    /// `DisplaySettingsModel()` in a preview reads `UserDefaults.standard`, so
    /// the canvas shows whatever the developer's own settings happen to be and
    /// a change in them looks like a change in the view. The domain is named
    /// apart and cleared first, so the values are fixed and reading them cannot
    /// depend on anything already stored. Devanagari and Nepali month names are
    /// the interesting case: they exercise the non-Latin paths, which the
    /// defaults would never show.
    static var preview: DisplaySettingsModel {
        let suite = "NepalKit.PreviewSettings"
        guard let defaults = UserDefaults(suiteName: suite) else {
            preconditionFailure("Cannot create the preview preferences domain \(suite)")
        }
        defaults.removePersistentDomain(forName: suite)
        defaults.set(DigitScript.devanagari.rawValue, forKey: SettingsStore.digitScriptKey)
        defaults.set(MonthNameStyle.nepali.rawValue, forKey: SettingsStore.monthNameStyleKey)
        return DisplaySettingsModel(store: SettingsStore(defaults: defaults))
    }
    #endif
}
