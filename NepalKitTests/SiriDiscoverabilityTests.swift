// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Dibas Sigdel
import Foundation
import Testing
@testable import NepalKit

/// Ticket 11: the discoverability copy, and the claim it makes.
///
/// The section in Settings is the only place in the product that tells a user
/// this feature exists, so what it says is load-bearing in a way a cosmetic
/// string is not: the prototype established that voice parameter-filling and
/// what the same App Intents expose to Shortcuts are *different capabilities*
/// on macOS 26. Copy that implied conversational conversions work by voice
/// would send people to an answer of "late June or early July" from a web
/// search, which is the exact gap the feature exists to close.
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
        // The sentence's two halves must stay distinct claims. If either were
        // dropped the section would imply something the prototype showed does
        // not work: voice for the conversions, or Shortcuts for today.
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
        // The whole point of showing phrases is that they work. A list typed
        // out here would be free to drift from `NepalKitShortcuts` — and a
        // Settings section that teaches a phrase the system does not know is
        // worse than no section at all, because it is confidently wrong.
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
        // The section is the first place a screen-reader user meets this
        // feature, so a phrase carrying an arrow or an ellipsis would be read
        // as noise in front of the words that matter.
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
        // The spec is explicit and gives the reason: the popover footer is
        // icon-only with no room for a sentence, and the popover stays focused
        // on the calendar. A hint added there would be the first thing to
        // appear without a decision being recorded.
        let source = try String(
            contentsOf: Self.repositoryRoot.appendingPathComponent("NepalKit/PopoverView.swift"),
            encoding: .utf8
        )

        #expect(!source.contains("Siri"))
        #expect(!source.contains("Shortcuts"))
    }
}
