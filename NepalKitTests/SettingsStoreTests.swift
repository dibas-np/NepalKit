// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Dibas Sigdel
import Foundation
import Testing
import NepalKitCore
@testable import NepalKit

struct SettingsStoreTests {
    private func freshStore() throws -> (SettingsStore, UserDefaults) {
        let suiteName = "NepalKitTests-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        return (SettingsStore(defaults: defaults), defaults)
    }

    @Test func defaultsWhenNothingStored() throws {
        let (store, _) = try freshStore()

        #expect(store.settings == DisplaySettings(digits: .latin, monthNames: .transliterated))
    }

    @Test func saveLoadRoundTrip() throws {
        let (store, _) = try freshStore()
        let settings = DisplaySettings(digits: .devanagari, monthNames: .nepali)

        store.save(settings)

        #expect(store.settings == settings)
    }

    @Test func settingsSurviveAcrossInstances() throws {
        let (_, defaults) = try freshStore()
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

    @Test func corruptValuesFallBackToDefaults() throws {
        let (store, defaults) = try freshStore()
        defaults.set("klingon", forKey: SettingsStore.digitScriptKey)
        defaults.set("", forKey: SettingsStore.monthNameStyleKey)

        #expect(store.settings == DisplaySettings(digits: .latin, monthNames: .transliterated))
    }
    // Ticket 12's question — do settings survive an in-place update? — is
    // answered by `SettingsStore.init`'s contract rather than by a test. The
    // property it needed to be asked (`persistenceIsVersionIndependent`)
    // existed only to be read here, and asserted nothing a caller could not
    // already see in the default argument three lines away; testing the real
    // thing instead would mean writing to `UserDefaults.standard`, which
    // clobbers the developer's own settings. The constraint is stated where a
    // re-scoping would be made.
}
