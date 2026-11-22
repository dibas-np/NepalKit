// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Dibas Sigdel
import Foundation
import Testing
import NepalKitCore
@testable import NepalKit

@MainActor
struct DisplaySettingsModelTests {
    private func freshModel() throws -> DisplaySettingsModel {
        let suiteName = "NepalKitTests-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        return DisplaySettingsModel(store: SettingsStore(defaults: defaults))
    }

    private func menuBar() throws -> MenuBarModel {
        MenuBarModel(now: try RoundTripFixtures.date(2026, 9, 27, 12, 0), refreshes: false, schedulesMidnightFire: false)
    }

    @Test("Menu-bar title honors both display axes")
    func menuBarTitleHonorsSettings() throws {
        let bar = try menuBar()

        #expect(bar.title(settings: DisplaySettings(digits: .latin, monthNames: .transliterated)) == "11 Ashoj")
        #expect(bar.title(settings: DisplaySettings(digits: .devanagari, monthNames: .nepali)) == "११ असोज")
        #expect(bar.title(settings: DisplaySettings(digits: .latin, monthNames: .nepali)) == "11 असोज")
        #expect(bar.title(settings: DisplaySettings(digits: .devanagari, monthNames: .transliterated)) == "११ Ashoj")
    }

    @Test("An update awaiting attention marks the menu-bar date")
    func updateMarkerPrefixesTheDateRatherThanReplacingIt() throws {
        let bar = try menuBar()
        let settings = DisplaySettings(digits: .latin, monthNames: .transliterated)

        #expect(bar.title(settings: settings, updateAvailable: true) == "! 11 Ashoj")
        #expect(bar.title(settings: settings, updateAvailable: false) == "11 Ashoj")
    }

    @Test("The update marker is announced as words, not as the glyph")
    func updateMarkerIsSpokenAsWords() throws {
        let bar = try menuBar()
        let settings = DisplaySettings(digits: .latin, monthNames: .transliterated)

        let spoken = bar.spokenTitle(settings: settings, updateAvailable: true)
        #expect(!spoken.contains(Strings.menuBarUpdateMarker))
        #expect(spoken.hasPrefix(Strings.appNameForSpeech), "the app name must stay first: \(spoken)")
        #expect(spoken.contains(Strings.updateAvailableSpoken))
        #expect(spoken.contains("Ashoj"), "the date is still announced after the reminder")
        #expect(bar.spokenTitle(settings: settings, updateAvailable: false) == bar.spokenTitle(settings: settings))
    }

    @Test("The reminder is still announced past the supported range")
    func reminderSurvivesTheRangeBoundary() throws {
        let bar = MenuBarModel(
            now: try TestDates.utc(2030, 1, 15, 6, 0), refreshes: false, schedulesMidnightFire: false
        )
        let settings = DisplaySettings(digits: .latin, monthNames: .transliterated)

        #expect(bar.title(settings: settings) == Strings.menuBarBeyondRange)
        #expect(bar.spokenTitle(settings: settings, updateAvailable: true).contains(Strings.updateAvailableSpoken))
    }

    @Test("The marker never appears in the spoken channel of an unmarked menu bar")
    func noMarkerWithoutAnUpdate() throws {
        let bar = try menuBar()

        for style in [MonthNameStyle.nepali, .transliterated] {
            let spoken = bar.spokenTitle(
                settings: DisplaySettings(digits: .latin, monthNames: style)
            )
            #expect(!spoken.contains("!"), "an exclamation mark reached the spoken channel: \(spoken)")
        }
    }

    @Test("Menu bar and popover render the same date for the same settings")
    func menuBarMatchesPopoverForSameSettings() throws {
        let now = try RoundTripFixtures.date(2026, 9, 27, 12, 0)
        let bar = try menuBar()

        for settings in [
            DisplaySettings(digits: .latin, monthNames: .transliterated),
            DisplaySettings(digits: .devanagari, monthNames: .nepali),
        ] {
            guard let today = BikramSambatDate.today(now: now, in: .v2) else {
                Issue.record("no date")
                return
            }
            #expect(bar.title(settings: settings) == today.formatted(settings, includesYear: false))
            #expect(today.formatted(settings).hasPrefix(bar.title(settings: settings)))
        }
    }

    @Test func savingDigitsPreservesMonthNames() throws {
        let model = try freshModel()
        model.save(monthNames: .nepali)

        model.save(digits: .devanagari)

        #expect(model.settings == DisplaySettings(digits: .devanagari, monthNames: .nepali))
    }

    @Test func savingMonthNamesPreservesDigits() throws {
        let model = try freshModel()
        model.save(digits: .devanagari)

        model.save(monthNames: .nepali)

        #expect(model.settings == DisplaySettings(digits: .devanagari, monthNames: .nepali))
    }

    @Test("Model writes through to the store")
    func modelPersistsThroughStore() throws {
        let suiteName = "NepalKitTests-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        let store = SettingsStore(defaults: defaults)
        let model = DisplaySettingsModel(store: store)

        model.save(digits: .devanagari)
        model.save(monthNames: .nepali)

        let relaunched = DisplaySettingsModel(store: SettingsStore(defaults: defaults))
        #expect(relaunched.settings == DisplaySettings(digits: .devanagari, monthNames: .nepali))
    }

    @Test func startsFromStoreDefaults() throws {
        #expect(try freshModel().settings == DisplaySettings(digits: .latin, monthNames: .transliterated))
    }

    @Test("The Settings pickers' bindings save through the model")
    func pickerBindingsSave() throws {
        let model = try freshModel()
        model.digits = .devanagari
        model.monthNames = .nepali
        #expect(model.digits == .devanagari)
        #expect(model.monthNames == .nepali)
        #expect(model.settings == DisplaySettings(digits: .devanagari, monthNames: .nepali))
    }

    @Test("Previews read fixed non-default settings")
    func previewSettingsAreFixedAndNonDefault() {
        let first = DisplaySettingsModel.preview
        first.save(DisplaySettings(digits: .latin, monthNames: .transliterated))
        #expect(DisplaySettingsModel.preview.settings == DisplaySettings(digits: .devanagari, monthNames: .nepali))
    }
}

enum RoundTripFixtures {
    static func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int, _ minute: Int) throws -> Date {
        try TestDates.utc(year, month, day, hour, minute)
    }
}
