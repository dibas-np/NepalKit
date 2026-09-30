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
/// because a test of a hand-copied constant proves nothing. Both literals are
/// read from the project-level configurations, which is where they were hoisted
/// to so that one value each feeds every target.
@MainActor
struct BuildNumberTests {
    /// A file relative to the checkout root, found by walking up from this file
    /// until it appears.
    ///
    /// Searched for by what is in each directory rather than by a fixed number
    /// of hops, because this file sits at a different depth in each of the two
    /// ways it is compiled: two levels under the repo root in the Xcode
    /// `NepalKitTests` target, and five in the `scripts/apptests` harness,
    /// which reaches these sources through a symlink. A fixed hop count was
    /// right for one of those and overshot the checkout in the other, which made
    /// every assertion here read `missing` — the test target could not build
    /// while that was true, so nothing ran it.
    private static func checkoutFile(_ relativePath: String) -> URL {
        var directory = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        while directory.path != "/" {
            let candidate = directory.appendingPathComponent(relativePath)
            if FileManager.default.fileExists(atPath: candidate.path) { return candidate }
            directory.deleteLastPathComponent()
        }
        // Unreachable while this test file lives inside the checkout, and the
        // assertions below report a missing file rather than trapping, so a
        // relocation fails as a test failure with a readable message.
        return directory.appendingPathComponent(relativePath)
    }

    private static var projectFileURL: URL { checkoutFile("NepalKit.xcodeproj/project.pbxproj") }

    /// The pbxproj label of a project-level **build configuration** block.
    ///
    /// Spelled `configuration for PBXProject "NepalKit"` rather than the
    /// shorter `for PBXProject "NepalKit"` on purpose. The shorter form is a
    /// substring of `Build configuration list for PBXProject "NepalKit"`, the
    /// `XCConfigurationList` that only *references* the configurations, so it
    /// matches three blocks instead of two. Harmless while the marker was only
    /// ever used to take the first setting found — the list holds references,
    /// not assignments — which is exactly why it went unnoticed until something
    /// counted the blocks rather than reading from them. The configuration list
    /// has no build settings of its own, so a marker loose enough to include it
    /// cannot report a value; it can only misreport how many homes a setting has.
    private static let configurationMarker = "configuration for PBXProject \"NepalKit\" */ = {"

    /// The pbxproj label of the app **target's** build configuration block.
    ///
    /// Needed because Xcode does not keep the marketing version at project level.
    /// Editing it in the UI writes it into the target's own configuration, which
    /// is why ADR-0003 records that the floor "is not something the file
    /// preserves" at one location. Reading only `configurationMarker` therefore
    /// found nothing and reported a valid version as missing.
    private static let targetConfigurationMarker = "configuration for PBXNativeTarget \"NepalKit\" */ = {"

    /// The body of every configuration block pbxproj labels with `marker`.
    ///
    /// Brace-matched from the label rather than gathered by searching for the
    /// setting being read, because a search by name cannot report *which*
    /// configuration it read. That distinction is the whole reason this file
    /// parses structure instead of grepping, and it has already been got wrong
    /// here once.
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

    /// Reads a build setting from the app's configuration blocks.
    ///
    /// Both project-level and target-level are read, because Xcode does not keep
    /// both literals in one place. Editing the marketing version in the UI writes
    /// it into the target's own configuration; the build number is commonly left
    /// at project level. A reader scoped to either one alone reports a perfectly
    /// valid setting as missing, which is how this file's correct 1.4.0 failed the
    /// release gate.
    ///
    /// Scope is still the point, and it is still the block rather than the
    /// setting name: an earlier version of this test searched the rest of the
    /// file after the app's bundle identifier, which swept in the test target's
    /// own configuration, so it could not tell the two targets apart and only
    /// passed because they happened to hold the same value — a test that reads
    /// the wrong value is worse than no test, because it reports success.
    /// Reading the blocks does not by itself prevent a repeat: the day a
    /// target-level copy is added back holding something else, this would read
    /// the project-level value, see a well-formed version, and pass. So scope
    /// is half the guard; `versionLiteralsHaveOneHomeAndOneValue` is the other
    /// half, and between them the earlier failure cannot come back quietly.
    private static func buildSetting(_ key: String) -> String? {
        guard let text = try? String(contentsOf: projectFileURL, encoding: .utf8) else { return nil }
        // Read every configuration that can carry this setting, not only the
        // project-level ones. Xcode writes MARKETING_VERSION into the *target's*
        // configuration when it is changed in the UI - it materialises the
        // inherited value rather than editing the project block - so a
        // project-level-only scan finds nothing and reports a valid version as
        // "missing". That is what failed the release gate on 1.4.0: the file was
        // correct and this reader was not.
        //
        // Project level is still searched first so that a value inherited from
        // there wins over a target-level override, which is the order Xcode
        // itself resolves them in. Every block found is required to agree, so a
        // genuine disagreement fails rather than resolving to whichever was
        // found first.
        let configurations = blocks(in: text, marker: configurationMarker)
            + blocks(in: text, marker: targetConfigurationMarker)
        guard !configurations.isEmpty else { return nil }
        let values = configurations.compactMap { block -> String? in
            block.components(separatedBy: "\n")
                .first { $0.contains("\(key) = ") }?
                .components(separatedBy: " = ").last?
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .trimmingCharacters(in: CharacterSet(charactersIn: ";"))
        }
        return values.first
    }

    /// Every line in the project file that assigns `key`, as `(line, value)`.
    ///
    /// Scans the whole file rather than the project blocks, because the question
    /// this answers is whether an assignment exists *anywhere else* — the
    /// re-added target-level copy that block-scoped reading cannot see. Trimmed
    /// of the trailing `;` so the values compare equal to the ones read above.
    private static func assignments(of key: String) -> [(line: Int, value: String)] {
        guard let text = try? String(contentsOf: projectFileURL, encoding: .utf8) else { return [] }
        let prefix = "\(key) = "
        return text.split(separator: "\n", omittingEmptySubsequences: false).enumerated().compactMap { index, raw in
            let line = raw.trimmingCharacters(in: .whitespaces)
            guard line.hasPrefix(prefix) else { return nil }
            let value = line.dropFirst(prefix.count)
                .trimmingCharacters(in: CharacterSet(charactersIn: ";"))
                .trimmingCharacters(in: .whitespaces)
            return (line: index + 1, value: value)
        }
    }

    @Test func versionLiteralsHaveOneHomeAndOneValue() {
        // Every copy of these literals must say the same thing.
        //
        // It deliberately does NOT count assignments against the number of
        // configurations. Xcode splits the two: editing the marketing version in
        // the UI writes it into the target's own configuration (ADR-0003), while
        // the build number is commonly left at project level, so a literal is
        // legitimately absent from half the blocks and inherits the rest. There
        // are four configurations and two assignments apiece, and no count-based
        // expectation can be true of that.
        //
        // An earlier version asserted "one per project configuration, and none at
        // a target level" — not a property this project has. It passed only
        // because two target-level assignments happened to equal the two
        // project-level blocks, so the numbers matched for the wrong reason.
        // What actually matters is agreement: if any two copies disagree, what
        // ships depends on which configuration gets built, and that is the whole
        // failure this test exists to catch.
        guard let text = try? String(contentsOf: Self.projectFileURL, encoding: .utf8) else {
            Issue.record("project.pbxproj could not be read at \(Self.projectFileURL.path)")
            return
        }
        #expect(
            !Self.blocks(in: text, marker: Self.configurationMarker).isEmpty,
            "no configuration block was found to read them from"
        )

        for key in ["MARKETING_VERSION", "CURRENT_PROJECT_VERSION"] {
            let found = Self.assignments(of: key)
            let where_ = found.map { "\($0.line)=\($0.value)" }.joined(separator: ", ")
            #expect(
                !found.isEmpty,
                "\(key) is not assigned anywhere in the project file, so its value is whatever Xcode defaults to"
            )
            #expect(
                Set(found.map(\.value)).count == 1,
                "\(key) resolves differently per configuration, so what ships depends on which one is built: [\(where_)]"
            )
        }
    }

    @Test func buildNumberIsAnInteger() {
        // Sparkle requires a properly formatted, increasing integer. Anything
        // else is silently unordered.
        let raw = Self.buildSetting("CURRENT_PROJECT_VERSION")

        #expect(raw.flatMap(Int.init) != nil, "CURRENT_PROJECT_VERSION is not an integer: \(raw ?? "missing")")
    }

    @Test func buildNumberIsPositive() {
        let raw = Self.buildSetting("CURRENT_PROJECT_VERSION")

        #expect((raw.flatMap(Int.init) ?? 0) >= 1)
    }

    @Test func shortVersionIsSemanticVersion() {
        // ADR-0009: Git tags, the Sparkle enclosure filename and the Homebrew
        // cask all derive from this value, so its shape is a release contract
        // rather than a formatting preference. Three numeric components is what
        // makes "1.3" and "1.3.0" the same release to every one of them.
        let short = Self.buildSetting("MARKETING_VERSION") ?? ""
        let components = short.split(separator: ".")

        #expect(
            components.count == 3 && components.allSatisfy { Int($0) != nil },
            "MARKETING_VERSION is not major.minor.patch with numeric components: \(short.isEmpty ? "missing" : short)"
        )
    }

    @Test func buildNumberIsDisjointFromTheShortVersion() {
        // ADR-0009: the two are tracked independently, so the updater's
        // comparator can never read one as the other. The hazard is specific —
        // "1.0" and "1" are different strings and the same number, so a build
        // number sitting at the short version's value is a release the updater
        // silently declines to offer. A three-component version cannot be read
        // as an integer at all, which makes the disjointness structural; this
        // guards the shape that delivers it rather than re-deriving it.
        let short = Self.buildSetting("MARKETING_VERSION") ?? ""
        let build = Int(Self.buildSetting("CURRENT_PROJECT_VERSION") ?? "") ?? -1

        #expect(build >= 1, "CURRENT_PROJECT_VERSION is not a positive integer: \(Self.buildSetting("CURRENT_PROJECT_VERSION") ?? "missing")")
        #expect(
            Int(short) == nil,
            "MARKETING_VERSION is \(short), which reads as the build number — the updater orders on the latter and About shows the former"
        )
    }

    @Test func buildNumberHasNotRegressedBelowTheLastReleased() {
        // The monotonic half of the invariant. If someone lowers
        // CURRENT_PROJECT_VERSION below the highest build the feed has already
        // offered, every installed copy stops being offered updates, silently.
        let current = Int(Self.buildSetting("CURRENT_PROJECT_VERSION") ?? "") ?? 0
        let floor = Self.lastReleasedBuildNumber

        #expect(
            floor > 0,
            "no published build number could be read from appcast.xml, so this guard is inert"
        )
        #expect(
            current >= floor,
            "build number \(current) is below the last released \(floor)"
        )
    }

    /// The highest build number ever published.
    ///
    /// A hand-maintained constant, and it has been wrong: it read 3 for several
    /// releases after build 4 shipped as 1.2, which left this guard
    /// permitting a drop back to 3. The appcast is the record of what actually
    /// shipped, so the floor is derived from it — a constant that silently lags
    /// a release is worse than no guard, because it reads as a guard.
    private static var lastReleasedBuildNumber: Int {
        let appcast = checkoutFile("appcast.xml")
        guard let text = try? String(contentsOf: appcast, encoding: .utf8) else { return 0 }
        let pattern = try? NSRegularExpression(pattern: "<sparkle:version>(\\d+)</sparkle:version>")
        let range = NSRange(text.startIndex..., in: text)
        return pattern?.matches(in: text, range: range)
            .compactMap { Int(text[Range($0.range(at: 1), in: text)!]) }
            .max() ?? 0
    }
}
