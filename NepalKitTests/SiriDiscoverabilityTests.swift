// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Dibas Sigdel
import Foundation
import Testing
@testable import NepalKit

/// The Siri and Shortcuts copy in Settings. It is the only place that tells a
/// user the feature exists, so it must not claim more than works.
struct SiriDiscoverabilityTests {
    private static var repositoryRoot: URL {
        for base in [URL(fileURLWithPath: #filePath), URL(fileURLWithPath: #filePath).standardizedFileURL] {
            var dir = base.deletingLastPathComponent()
            for _ in 0 ..< 10 {
                if FileManager.default.fileExists(atPath: dir.appendingPathComponent("NepalKit.xcodeproj").path) {
                    return dir
                }
                dir = dir.deletingLastPathComponent()
            }
        }
        return URL(fileURLWithPath: #filePath).deletingLastPathComponent()
    }

    @Test("The section leads with the split sentence, verbatim")
    func summaryStatesWhatActuallyWorks() {
        #expect(Strings.siriShortcutsSection == "Siri & Shortcuts")
        #expect(
            Strings.siriShortcutsSummary
                == "Ask Siri for today's, tomorrow's or yesterday's Nepali date; run the conversions from Shortcuts."
        )
        // Both halves must stay, or the section implies a capability that
        // doesn't work.
        #expect(Strings.siriShortcutsSummary.contains("Ask Siri"))
        #expect(Strings.siriShortcutsSummary.contains("Shortcuts"))
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
            // The token is written out as the app's name: the phrase is taught
            // as text, and `\(.applicationName)` would be shown literally.
            #expect(capability.phrase.contains(Strings.appName))
            #expect(!capability.phrase.contains(".applicationName"))
            #expect(capability.spokenDescription.hasPrefix(capability.title))
            #expect(capability.spokenDescription.contains(capability.phrase))
        }

        // Identity has to be unique or SwiftUI collapses the rows.
        #expect(Set(capabilities.map(\.id)).count == capabilities.count)
    }

    @Test("The listed phrases are the ones the provider registers")
    func listedPhrasesMatchTheRegisteredShortcuts() throws {
        // A phrase the system doesn't know is worse than none, so the list is
        // checked against `NepalKitShortcuts`.
        let source = try String(
            contentsOf: Self.repositoryRoot.appendingPathComponent("NepalKit/AppIntents/NepalKitShortcuts.swift"),
            encoding: .utf8
        )

        for capability in Strings.siriShortcutCapabilities {
            // The provider writes the application-name token as an
            // interpolation; Settings spells out what it resolves to.
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
        // A screen reader would read arrows or ellipses as noise.
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
        // App Shortcuts phrases load per app localization: a phrase missing
        // from the catalog registers nothing, silently, while the build and
        // metadata extraction still succeed.
        let data = try Data(contentsOf: Self.repositoryRoot.appendingPathComponent("NepalKit/AppShortcuts.xcstrings"))
        let catalog = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        let strings = try #require(catalog["strings"] as? [String: Any])

        for capability in Strings.siriShortcutCapabilities {
            let key = capability.phrase.replacing(Strings.appName, with: "${applicationName}")
            #expect(strings[key] != nil, "catalog is missing \(key)")
        }
    }

    @Test("The provider stays within the ten-shortcut cap")
    func providerStaysUnderTheShortcutCap() {
        #expect(NepalKitShortcuts.appShortcuts.count <= 10)
    }

    @Test("The popover carries no Siri hint")
    func popoverStaysUntouched() throws {
        // The popover footer has no room for a sentence.
        let source = try String(
            contentsOf: Self.repositoryRoot.appendingPathComponent("NepalKit/PopoverView.swift"),
            encoding: .utf8
        )

        #expect(!source.contains("Siri"))
        #expect(!source.contains("Shortcuts"))
    }
}
