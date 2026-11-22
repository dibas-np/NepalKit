// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Dibas Sigdel
import Foundation
import Testing
@testable import NepalKit

struct SiriDiscoverabilityTests {
    @Test("The section leads with the split sentence, verbatim")
    func summaryStatesWhatActuallyWorks() {
        #expect(Strings.siriShortcutsSection == "Siri & Shortcuts")
        #expect(
            Strings.siriShortcutsSummary
                == "Ask Siri for today's, tomorrow's or yesterday's Nepali date; run the conversions from Shortcuts."
        )
    }

    @Test("All five registered capabilities are listed with their phrases")
    func everyCapabilityIsListedWithAPhrase() {
        let capabilities = Strings.siriShortcutCapabilities

        #expect(capabilities.count == 5)
        #expect(capabilities.map(\.title) == [
            Strings.siriTodayCapability,
            Strings.siriTomorrowCapability,
            Strings.siriYesterdayCapability,
            Strings.siriConvertToBSCapability,
            Strings.siriConvertToGregorianCapability,
        ])

        for capability in capabilities {
            #expect(!capability.title.isEmpty)
            #expect(capability.phrase.contains(Strings.appName))
            #expect(!capability.phrase.contains(".applicationName"))
            #expect(capability.spokenDescription.hasPrefix(capability.title))
            #expect(capability.spokenDescription.contains(capability.phrase))
        }

        #expect(Set(capabilities.map(\.id)).count == capabilities.count)
    }

    @Test("The listed phrases are the ones the provider registers")
    func listedPhrasesMatchTheRegisteredShortcuts() throws {
        let source = try String(
            contentsOf: Repository.root.appendingPathComponent("NepalKit/AppIntents/NepalKitShortcuts.swift"),
            encoding: .utf8
        )

        for capability in Strings.siriShortcutCapabilities {
            let template = capability.phrase.replacing(
                Strings.appName,
                with: "\\(.applicationName)"
            )
            #expect(
                source.contains("\"" + template + "\""),
                "Settings lists a phrase the provider does not register: \(capability.phrase)"
            )
        }
    }

    @Test("No listed phrase is announced as a typographic or symbol-laden string")
    func phrasesAreAnnouncedCleanly() {
        let forbidden: Set<Character> = [
            "\u{2013}", "\u{2014}", "\u{2192}", "\u{2190}", "\u{2026}", "\u{00B7}",
        ]
        var offenders: [String] = []

        for capability in Strings.siriShortcutCapabilities {
            if capability.phrase.contains(where: { forbidden.contains($0) }) {
                offenders.append(capability.phrase)
            }
            if capability.spokenDescription.contains(where: { forbidden.contains($0) }) {
                offenders.append(capability.spokenDescription)
            }
        }

        #expect(offenders.isEmpty, "typographic characters in the discoverability copy: \(offenders)")
    }

    @Test("Every listed phrase has its catalog template, or it never registers")
    func listedPhrasesHaveCatalogEntries() throws {
        let data = try Data(contentsOf: Repository.root.appendingPathComponent("NepalKit/AppShortcuts.xcstrings"))
        let catalog = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        let strings = try #require(catalog["strings"] as? [String: Any])

        for capability in Strings.siriShortcutCapabilities {
            let key = capability.phrase.replacing(Strings.appName, with: "${applicationName}")
            #expect(strings[key] != nil, "catalog is missing \(key)")
        }
    }

    @Test("The popover carries no Siri hint")
    func popoverStaysUntouched() throws {
        let source = try String(
            contentsOf: Repository.root.appendingPathComponent("NepalKit/PopoverView.swift"),
            encoding: .utf8
        )

        #expect(!source.contains("Siri"))
        #expect(!source.contains("Shortcuts"))
    }
}
