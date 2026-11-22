// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Dibas Sigdel
import Foundation
import Testing
@testable import NepalKit

@MainActor
struct BuildNumberTests {
    private static var projectFileURL: URL { Repository.file("NepalKit.xcodeproj/project.pbxproj") }

    private static let configurationMarker = "configuration for PBXProject \"NepalKit\" */ = {"

    private static func blocks(in text: String, marker: String) -> [String] {
        var found: [String] = []
        var searchStart = text.startIndex
        while let range = text.range(of: marker, range: searchStart..<text.endIndex) {
            var depth = 1
            var index = range.upperBound
            while depth > 0, index < text.endIndex {
                if text[index] == "{" { depth += 1 }
                if text[index] == "}" { depth -= 1 }
                index = text.index(after: index)
            }
            found.append(String(text[range.upperBound..<index]))
            searchStart = index
        }
        return found
    }

    private static func buildSetting(_ key: String) -> String? {
        guard let text = try? String(contentsOf: projectFileURL, encoding: .utf8) else { return nil }
        return effectiveValues(key, target: "NepalKit", in: text).first
    }

    private static func effectiveValues(_ key: String, target: String, in text: String) -> [String] {
        let projectBlocks = blocks(in: text, marker: configurationMarker)
        let targetBlocks = blocks(in: text, marker: "configuration for PBXNativeTarget \"\(target)\" */ = {")
        return targetBlocks.compactMap { block in
            if let value = setting(key, in: block) { return value }
            guard let name = setting("name", in: block),
                  let inherited = projectBlocks.first(where: { setting("name", in: $0) == name }) else { return nil }
            return setting(key, in: inherited)
        }
    }

    private static func setting(_ key: String, in block: String) -> String? {
        block.split(separator: "\n").lazy.map { $0.trimmingCharacters(in: .whitespaces) }
            .first { $0.hasPrefix("\(key) = ") }?
            .dropFirst(key.count + 3)
            .trimmingCharacters(in: CharacterSet(charactersIn: ";\""))
    }

    @Test func releaseVersionsAgreeWithinEachProduct() throws {
        let text = try String(contentsOf: Self.projectFileURL, encoding: .utf8)
        for key in ["MARKETING_VERSION", "CURRENT_PROJECT_VERSION"] {
            let macValues = Self.effectiveValues(key, target: "NepalKit", in: text)
            #expect(macValues.count == 2, "Mac Debug and Release must each resolve \(key)")
            #expect(Set(macValues).count == 1, "Mac configurations disagree on \(key)")

            let watchTargets = ["NepalKitWatch", "NepalKitWatch Watch App", "NepalKitComplications"]
            let watchValues = watchTargets.flatMap { target in
                let values = Self.effectiveValues(key, target: target, in: text)
                #expect(values.count == 2, "\(target) Debug and Release must each resolve \(key)")
                return values
            }
            #expect(Set(watchValues).count == 1, "Watch container, app and extension disagree on \(key)")
        }
    }

    @Test func buildNumberIsAPositiveInteger() {
        let raw = Self.buildSetting("CURRENT_PROJECT_VERSION")

        #expect((raw.flatMap(Int.init) ?? 0) >= 1, "CURRENT_PROJECT_VERSION is not a positive integer: \(raw ?? "missing")")
    }

    @Test func shortVersionIsSemanticVersion() {
        let short = Self.buildSetting("MARKETING_VERSION") ?? ""
        let components = short.split(separator: ".")

        #expect(
            components.count == 3 && components.allSatisfy { Int($0) != nil },
            "MARKETING_VERSION is not major.minor.patch with numeric components: \(short.isEmpty ? "missing" : short)"
        )
    }

    @Test func buildNumberIsDisjointFromTheShortVersion() {
        let short = Self.buildSetting("MARKETING_VERSION") ?? ""

        #expect(
            Int(short) == nil,
            "MARKETING_VERSION is \(short), which reads as the build number — the updater orders on the latter and About shows the former"
        )
    }

    @Test func buildNumberHasNotRegressedBelowTheLastReleased() throws {
        let current = Int(Self.buildSetting("CURRENT_PROJECT_VERSION") ?? "") ?? 0
        let floor = try Self.lastReleasedBuildNumber
        let short = Self.buildSetting("MARKETING_VERSION") ?? ""
        let alreadyReleased = try Self.releasedVersions.contains(short)

        #expect(
            floor > 0,
            "no published build number could be read from appcast.xml, so this guard is inert"
        )
        if alreadyReleased {
            #expect(
                current >= floor,
                "build number \(current) is below the last released \(floor)"
            )
        } else {
            #expect(
                current > floor,
                "build number \(current) must be higher than the last released \(floor): \(short) is not in the feed yet, and Sparkle offers an update only on a higher build"
            )
        }
    }

    private static var releasedVersions: Set<String> {
        get throws {
            let appcast = Repository.file("appcast.xml")
            guard let text = try? String(contentsOf: appcast, encoding: .utf8) else { return [] }
            let pattern = try? NSRegularExpression(
                pattern: "<sparkle:shortVersionString>([0-9.]+)</sparkle:shortVersionString>"
            )
            let range = NSRange(text.startIndex..., in: text)
            let versions = try pattern?.matches(in: text, range: range)
                .map { match -> String in
                    let range = try #require(Range(match.range(at: 1), in: text))
                    return String(text[range])
                } ?? []
            return Set(versions)
        }
    }

    private static var lastReleasedBuildNumber: Int {
        get throws {
            let appcast = Repository.file("appcast.xml")
            guard let text = try? String(contentsOf: appcast, encoding: .utf8) else { return 0 }
            let pattern = try? NSRegularExpression(pattern: "<sparkle:version>(\\d+)</sparkle:version>")
            let range = NSRange(text.startIndex..., in: text)
            return try pattern?.matches(in: text, range: range)
                .compactMap { match in
                    let range = try #require(Range(match.range(at: 1), in: text))
                    return Int(text[range])
                }
                .max() ?? 0
        }
    }
}
