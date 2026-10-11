// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Dibas Sigdel
import Foundation
import Testing
import NepalKitCore
@testable import NepalKit

/// The time-reference setting itself (ADR-0017): what it names, how it is
/// stored, and who hears that it changed.
@MainActor
struct TimeReferenceSettingTests {
    private func freshDefaults() throws -> UserDefaults {
        let suiteName = "NepalKitTests-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }

    @Test func eachReferenceNamesItsZone() {
        #expect(TimeReference.nepal.timeZone == nepalTimeZone)
        #expect(TimeReference.local.timeZone.identifier == TimeZone.autoupdatingCurrent.identifier)
    }

    @Test func theLocalOptionNamesTheZoneInWords() throws {
        let newYork = try #require(TimeZone(identifier: "America/New_York"))
        #expect(TimeReference.localZoneName(newYork, locale: Locale(identifier: "en_US")) == "Eastern Time")
        #expect(Strings.timeZoneLocal(zoneName: "Eastern Time") == "My time zone (Eastern Time)")
    }

    @Test func storeDefaultsToNepalTime() throws {
        #expect(SettingsStore(defaults: try freshDefaults()).timeReference == .nepal)
    }

    @Test(arguments: TimeReference.allCases)
    func storeRoundTripsAcrossInstances(reference: TimeReference) throws {
        let defaults = try freshDefaults()
        SettingsStore(defaults: defaults).save(reference)
        #expect(SettingsStore(defaults: defaults).timeReference == reference)
    }

    @Test func anUnknownStoredValueFallsBackToNepalTime() throws {
        let defaults = try freshDefaults()
        defaults.set("utc", forKey: SettingsStore.timeReferenceKey)
        #expect(SettingsStore(defaults: defaults).timeReference == .nepal)
    }

    @Test func theReferenceIsIndependentOfTheDisplaySettings() throws {
        let defaults = try freshDefaults()
        let store = SettingsStore(defaults: defaults)
        store.save(.local)
        store.save(DisplaySettings(digits: .devanagari, monthNames: .nepali))
        #expect(store.timeReference == .local)
        #expect(store.settings == DisplaySettings(digits: .devanagari, monthNames: .nepali))
    }

    @Test func modelLoadsPersistsAndNamesTheZone() throws {
        let defaults = try freshDefaults()
        let model = DisplaySettingsModel(store: SettingsStore(defaults: defaults))
        #expect(model.timeReference == .nepal)
        #expect(model.timeZone == nepalTimeZone)

        model.timeReferenceSelection = .local

        #expect(model.timeReference == .local)
        #expect(model.timeZone.identifier == TimeZone.autoupdatingCurrent.identifier)
        #expect(DisplaySettingsModel(store: SettingsStore(defaults: defaults)).timeReference == .local)
    }

    @Test func everyObserverHearsEachChange() throws {
        let model = DisplaySettingsModel(store: SettingsStore(defaults: try freshDefaults()))
        var first: [TimeReference] = []
        var second: [TimeReference] = []
        model.observeTimeReference { first.append($0) }
        model.observeTimeReference { second.append($0) }

        model.save(TimeReference.local)
        model.save(TimeReference.nepal)

        #expect(first == [.local, .nepal])
        #expect(second == [.local, .nepal])
    }

    @Test func theMenuBarFootnoteNamesTheClock() {
        #expect(Strings.menuBarTimeFootnote(.nepal) == "The time is Nepal Time, whatever your Mac's time zone.")
        #expect(Strings.menuBarTimeFootnote(.local) == "The time is your Mac's time zone, as chosen in General.")
    }
}
