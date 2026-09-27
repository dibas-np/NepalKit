import XCTest
@testable import NepalKitCore

final class DisplaySettingsStoreTests: XCTestCase {
    private func freshStore() -> (DisplaySettingsStore, UserDefaults) {
        let defaults = UserDefaults(suiteName: "NepalKitCoreTests-\(UUID().uuidString)")!
        defaults.removePersistentDomain(forName: "NepalKitCoreTests")
        return (DisplaySettingsStore(defaults: defaults), defaults)
    }

    func testDefaultsWhenNothingStored() {
        let (store, _) = freshStore()

        XCTAssertEqual(store.settings, DisplaySettings(digits: .latin, monthNames: .transliterated))
    }

    func testSaveLoadRoundTrip() {
        let (store, _) = freshStore()
        let settings = DisplaySettings(digits: .devanagari, monthNames: .nepali)

        store.save(settings)

        XCTAssertEqual(store.settings, settings)
    }

    func testSettingsSurviveAcrossInstances() {
        let (_, defaults) = freshStore()
        DisplaySettingsStore(defaults: defaults).save(
            DisplaySettings(digits: .devanagari, monthNames: .transliterated)
        )

        // A fresh instance over the same domain reads the saved values,
        // simulating an app relaunch.
        XCTAssertEqual(
            DisplaySettingsStore(defaults: defaults).settings,
            DisplaySettings(digits: .devanagari, monthNames: .transliterated)
        )
    }

    func testCorruptValuesFallBackToDefaults() {
        let (store, defaults) = freshStore()
        defaults.set("klingon", forKey: DisplaySettingsStore.digitScriptKey)
        defaults.set("", forKey: DisplaySettingsStore.monthNameStyleKey)

        XCTAssertEqual(store.settings, DisplaySettings(digits: .latin, monthNames: .transliterated))
    }
}
