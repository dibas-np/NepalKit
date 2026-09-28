// SPDX-License-Identifier: GPL-3.0-or-later
import Foundation
import Testing
import NepalKitCore
@testable import NepalKit

/// Display settings must reach every surface uniformly, and persist.
@MainActor
struct DisplaySettingsModelTests {
    private func freshModel() -> DisplaySettingsModel {
        let suiteName = "NepalKitTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return DisplaySettingsModel(store: SettingsStore(defaults: defaults))
    }

    private func menuBar() -> MenuBarModel {
        MenuBarModel(now: RoundTripFixtures.date(2026, 9, 27, 12, 0), refreshInterval: 3600)
    }

    @Test("Menu-bar title honors both display axes")
    func menuBarTitleHonorsSettings() {
        let bar = menuBar()

        #expect(bar.title(settings: DisplaySettings(digits: .latin, monthNames: .transliterated)) == "11 Ashoj")
        #expect(bar.title(settings: DisplaySettings(digits: .devanagari, monthNames: .nepali)) == "११ असोज")
        #expect(bar.title(settings: DisplaySettings(digits: .latin, monthNames: .nepali)) == "11 असोज")
        #expect(bar.title(settings: DisplaySettings(digits: .devanagari, monthNames: .transliterated)) == "११ Ashoj")
    }

    @Test("Menu bar and popover render the same date for the same settings")
    func menuBarMatchesPopoverForSameSettings() {
        let now = RoundTripFixtures.date(2026, 9, 27, 12, 0)
        let bar = menuBar()

        for settings in [
            DisplaySettings(digits: .latin, monthNames: .transliterated),
            DisplaySettings(digits: .devanagari, monthNames: .nepali),
        ] {
            guard let today = todayBS(now: now, in: .v2) else {
                Issue.record("no date")
                return
            }
            // The menu bar drops the year; the popover keeps it. Same date either way.
            #expect(bar.title(settings: settings) == formatBSShort(today, settings: settings))
            #expect(formatBS(today, settings: settings).hasPrefix(bar.title(settings: settings)))
        }
    }

    @Test func savingDigitsPreservesMonthNames() {
        let model = freshModel()
        model.save(monthNames: .nepali)

        model.save(digits: .devanagari)

        #expect(model.settings == DisplaySettings(digits: .devanagari, monthNames: .nepali))
    }

    @Test func savingMonthNamesPreservesDigits() {
        let model = freshModel()
        model.save(digits: .devanagari)

        model.save(monthNames: .nepali)

        #expect(model.settings == DisplaySettings(digits: .devanagari, monthNames: .nepali))
    }

    @Test("Model writes through to the store")
    func modelPersistsThroughStore() {
        let suiteName = "NepalKitTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        let store = SettingsStore(defaults: defaults)
        let model = DisplaySettingsModel(store: store)

        model.save(digits: .devanagari)
        model.save(monthNames: .nepali)

        // A fresh model over the same store sees the change: a relaunch keeps settings.
        let relaunched = DisplaySettingsModel(store: SettingsStore(defaults: defaults))
        #expect(relaunched.settings == DisplaySettings(digits: .devanagari, monthNames: .nepali))
    }

    @Test func startsFromStoreDefaults() {
        #expect(freshModel().settings == DisplaySettings(digits: .latin, monthNames: .transliterated))
    }
}

enum RoundTripFixtures {
    static func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int, _ minute: Int) -> Date {
        TestDates.utc(year, month, day, hour, minute)
    }
}
