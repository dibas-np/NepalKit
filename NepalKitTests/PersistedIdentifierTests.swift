// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Dibas Sigdel
import Foundation
import Testing
import NepalKitCore
@testable import NepalKit

/// Pins the identifiers users already have on disk. Written with literals
/// rather than the constants, because renaming any of these silently resets
/// every user's settings on upgrade.
@MainActor
struct PersistedIdentifierTests {
    private func freshDefaults() throws -> UserDefaults {
        let suiteName = "NepalKitTests-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }

    @Test func storedDisplaySettingsReadThroughTheLiteralKeysAndRawValues() throws {
        let defaults = try freshDefaults()
        defaults.set("devanagari", forKey: "digitScript")
        defaults.set("nepali", forKey: "monthNameStyle")

        #expect(SettingsStore(defaults: defaults).settings == DisplaySettings(digits: .devanagari, monthNames: .nepali))

        defaults.set("latin", forKey: "digitScript")
        defaults.set("transliterated", forKey: "monthNameStyle")

        #expect(SettingsStore(defaults: defaults).settings == DisplaySettings(digits: .latin, monthNames: .transliterated))
    }

    @Test func savedDisplaySettingsUseTheLiteralKeysAndRawValues() throws {
        let defaults = try freshDefaults()

        SettingsStore(defaults: defaults).save(DisplaySettings(digits: .devanagari, monthNames: .nepali))

        #expect(defaults.string(forKey: "digitScript") == "devanagari")
        #expect(defaults.string(forKey: "monthNameStyle") == "nepali")
    }

    @Test func loginItemConfiguredFlagUsesTheLiteralKey() throws {
        // A configured user must not be re-registered after they turned it off.
        let defaults = try freshDefaults()
        defaults.set(true, forKey: "loginItemConfigured")
        let service = LoginItemModelTests.MockService()

        LoginItemModel(service: service, defaults: defaults).ensureDefaultOn()

        #expect(service.registerCalls == 0)
    }
}
