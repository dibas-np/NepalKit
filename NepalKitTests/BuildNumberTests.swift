// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Dibas Sigdel
import Foundation
import Testing
@testable import NepalKit

/// The build number is load-bearing in a way nothing else notices.
///
/// Sparkle orders updates on `CFBundleVersion` and requires an increasing,
/// properly formatted integer. If a release ships the same build number twice,
/// or a non-integer one, the updater offers no update and the failure looks
/// like a Sparkle bug rather than a packaging mistake — and it is discovered by
/// users, not by CI. ADR-0009 records that a test guards this; this is that
/// test, and it reads the real project file rather than a value supplied to it,
/// because a test of a hand-copied constant proves nothing.
@MainActor
struct BuildNumberTests {
    /// The repo root, found by walking up from this file's location at runtime.
    /// The harness symlinks the real sources, so `NepalKitTests` resolves
    /// through `scripts/apptests/Tests/NepalKitTests` to the real directory;
    /// walking up from `#filePath` therefore lands in the repo either way.
    private static var projectFileURL: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()   // NepalKitTests
            .deletingLastPathComponent()   // Tests
            .deletingLastPathComponent()   // apptests or NepalKitCore
            .deletingLastPathComponent()   // scripts or NepalKit
            .deletingLastPathComponent()
            .appendingPathComponent("NepalKit.xcodeproj/project.pbxproj")
    }

    /// Reads a build setting from the **app target's** configuration blocks.
    ///
    /// Scoped by brace-matching from the block pbxproj labels
    /// `configuration for PBXNativeTarget "NepalKit"`, rather than by searching
    /// the rest of the file after the app's bundle identifier. That earlier
    /// approach swept in the test target's own configuration, so the test could
    /// not tell the two targets apart and only passed because they happened to
    /// hold the same value — a test that reads the wrong value is worse than no
    /// test, because it reports success.
    private static func buildSetting(_ key: String) -> String? {
        guard let text = try? String(contentsOf: projectFileURL, encoding: .utf8) else { return nil }
        let marker = "for PBXNativeTarget \"NepalKit\" */ = {"
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
        guard !found.isEmpty else { return nil }
        return found
            .flatMap { $0.components(separatedBy: "\n") }
            .first { $0.contains("\(key) = ") }?
            .components(separatedBy: " = ").last?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: ";"))
    }

    @Test func buildNumberIsAnInteger() {
        // Sparkle requires a properly formatted, increasing integer. Anything
        // else is silently unordered.
        let raw = try? #require(Self.buildSetting("CURRENT_PROJECT_VERSION"))

        #expect(raw.flatMap(Int.init) != nil, "CURRENT_PROJECT_VERSION is not an integer: \(raw ?? "missing")")
    }

    @Test func buildNumberIsPositive() {
        let raw = try? #require(Self.buildSetting("CURRENT_PROJECT_VERSION"))

        #expect((raw.flatMap(Int.init) ?? 0) >= 1)
    }

    @Test func buildNumberIsDisjointFromTheShortVersion() {
        // ADR-0009: the two are tracked independently and must stay disjoint, so
        // the updater's comparator can never read one as the other. Compared
        // *numerically*, not as strings — "1.0" and "1" are different strings
        // and the same number, which is precisely the conflation this guards
        // against. The build number is what moves on fixes a user never sees, so
        // it must not sit at the short version's value.
        let short = Double(Self.buildSetting("MARKETING_VERSION") ?? "") ?? -1
        let build = Int(Self.buildSetting("CURRENT_PROJECT_VERSION") ?? "") ?? -1

        #expect(short >= 0, "MARKETING_VERSION is not a number: \(Self.buildSetting("MARKETING_VERSION") ?? "missing")")
        #expect(build >= 1, "CURRENT_PROJECT_VERSION is not a positive integer: \(Self.buildSetting("CURRENT_PROJECT_VERSION") ?? "missing")")
        #expect(
            Double(build) != short,
            "build number \(build) equals short version \(short) — the updater orders on the former, and About shows the latter"
        )
    }

    @Test func buildNumberHasNotRegressedBelowTheLastReleased() {
        // The monotonic half of the invariant. `lastReleasedBuildNumber` is
        // raised as part of cutting a release; if someone lowers
        // CURRENT_PROJECT_VERSION below it, every installed copy stops being
        // offered updates, silently.
        let current = Int(Self.buildSetting("CURRENT_PROJECT_VERSION") ?? "") ?? 0

        #expect(
            current >= Self.lastReleasedBuildNumber,
            "build number \(current) is below the last released \(Self.lastReleasedBuildNumber)"
        )
    }

    /// The highest build number ever published. No release has been published
    /// yet, so this is 1 — the first release must carry a build number at or
    /// above it, and cutting a release raises it. This is the value that makes
    /// "the build number went backwards" a test failure rather than a support
    /// ticket a year later.
    private static let lastReleasedBuildNumber = 1
}
