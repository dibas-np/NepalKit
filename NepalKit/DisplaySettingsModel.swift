// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Dibas Sigdel
import Foundation
import Observation
import NepalKitCore

@MainActor
@Observable
final class DisplaySettingsModel {
    private(set) var settings: DisplaySettings
    private(set) var timeReference: TimeReference

    private let store: SettingsStore
    @ObservationIgnored private var timeReferenceObservers: [@MainActor (TimeReference) -> Void] = []

    init(store: SettingsStore? = nil) {
        let store = store ?? SettingsStore()
        self.store = store
        self.settings = store.settings
        self.timeReference = store.timeReference
    }

    var timeZone: TimeZone { timeReference.timeZone }

    func save(_ reference: TimeReference) {
        store.save(reference)
        timeReference = reference
        for observer in timeReferenceObservers {
            observer(reference)
        }
    }

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
