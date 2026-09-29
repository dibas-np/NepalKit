// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Dibas Sigdel
import Foundation
import Testing
import NepalKitCore
@testable import NepalKit

struct SettingsStoreTests {
    private func freshStore() -> (SettingsStore, UserDefaults) {
        let suiteName = "NepalKitTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return (SettingsStore(defaults: defaults), defaults)
    }

    @Test func defaultsWhenNothingStored() {
        let (store, _) = freshStore()

        #expect(store.settings == DisplaySettings(digits: .latin, monthNames: .transliterated))
    }

    @Test func saveLoadRoundTrip() {
        let (store, _) = freshStore()
        let settings = DisplaySettings(digits: .devanagari, monthNames: .nepali)

        store.save(settings)

        #expect(store.settings == settings)
    }

    @Test func settingsSurviveAcrossInstances() {
        let (_, defaults) = freshStore()
        SettingsStore(defaults: defaults).save(
            DisplaySettings(digits: .devanagari, monthNames: .transliterated)
        )

        // A fresh instance over the same domain reads the saved values,
        // simulating an app relaunch.
        #expect(
            SettingsStore(defaults: defaults).settings
                == DisplaySettings(digits: .devanagari, monthNames: .transliterated)
        )
    }

    @Test func corruptValuesFallBackToDefaults() {
        let (store, defaults) = freshStore()
        defaults.set("klingon", forKey: SettingsStore.digitScriptKey)
        defaults.set("", forKey: SettingsStore.monthNameStyleKey)

        #expect(store.settings == DisplaySettings(digits: .latin, monthNames: .transliterated))
    }
    @Test func theStoreIsNotScopedByAnythingAnUpdateWouldChange() {
        // The question ticket 12 asks: do settings survive an in-place update?
        // `SettingsStore` uses `UserDefaults.standard`, so the preferences are
        // written to the app's own plist keyed by bundle identifier. An in-place
        // update replaces the binary and leaves that plist alone.
        //
        // An earlier version of this test asked `UserDefaults` which domains were
        // volatile and failed to notice when the store was deliberately
        // re-scoped to a versioned suite - the domain list does not reflect an
        // explicitly created suite, so the assertion was checking nothing. It is
        // replaced with the direct property: the store must hold `.standard`.
        let store = SettingsStore()
        #expect(
            store.persistenceIsVersionIndependent,
            "the defaults store is scoped to something an update would replace"
        )
    }
}
