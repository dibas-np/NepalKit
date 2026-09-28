// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Dibas Sigdel
import AppKit
import Testing
@testable import NepalKit

/// An unresolvable SF Symbol name renders as *nothing at all* — no error, no
/// fallback, no warning. A typo is therefore invisible to the compiler and to
/// every other test, and only shows up when a human looks at the screen. These
/// tests turn that silent failure into a suite failure.
///
/// The second half is the part that cannot be automated: whether a symbol
/// reinforces its label is a design judgement. It is recorded as a comment on
/// each name in `Symbols` so it is reviewable, not asserted here.
@MainActor
struct SymbolTests {
    @Test func everySymbolResolves() {
        for name in Symbols.all {
            #expect(
                NSImage(systemSymbolName: name, accessibilityDescription: nil) != nil,
                "\(name) does not resolve and would render as nothing"
            )
        }
    }

    @Test func symbolsAreDistinct() {
        // Two names that collapse to the same glyph would silently lose the
        // distinction they exist to make.
        #expect(Set(Symbols.all).count == Symbols.all.count)
    }

    @Test func everySymbolIsReachableFromTheApp() throws {
        // A name in `all` that no view renders is a maintenance trap: the
        // resolve-and-distinct tests pass on it happily, so it looks maintained
        // while being unreachable. Four entries were deleted from `Symbols` on
        // exactly this basis when the popover's clock rows moved from glyphs to
        // typographic labels.
        //
        // Sources are read from disk because SwiftUI builds view trees by type
        // erasure, leaving nothing to introspect at runtime.
        //
        // The comparison is on the constant name, not the SF Symbol string: a
        // view writes `Symbols.launchAtLogin`, never `"power"`. An earlier
        // version of this test searched for the symbol string and consequently
        // reported every surviving symbol as unreachable, which is how it was
        // caught.
        let sources = try Self.appSources()
        #expect(!sources.isEmpty, "found no app sources at all — the path walk is broken")

        for constant in try Self.declaredConstants() {
            #expect(
                Self.constants.contains(constant),
                "Symbols declares \(constant) but never lists it in `all`, so no test resolves it"
            )
            let uses = "Symbols.\(constant)"
            #expect(
                sources.contains { $0.contains(uses) },
                "Symbols.\(constant) is listed in `all` but no view references it"
            )
        }
    }

    private static func appSources() throws -> [String] {
        let appDir = repositoryRoot.appendingPathComponent("NepalKit")
        let names = try FileManager.default.contentsOfDirectory(atPath: appDir.path)
        return try names
            .filter { $0.hasSuffix(".swift") && $0 != "Symbols.swift" }
            .map { try String(contentsOf: appDir.appendingPathComponent($0), encoding: .utf8) }
    }

    /// Constants declared on `Symbols`, parsed from its source. `all` is a list
    /// literal, so it is checked separately rather than parsed as a declaration.
    private static func declaredConstants() throws -> [String] {
        let text = try String(
            contentsOf: repositoryRoot.appendingPathComponent("NepalKit/Symbols.swift"),
            encoding: .utf8
        )
        return text
            .split(separator: "\n")
            .compactMap { line -> String? in
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                guard trimmed.hasPrefix("static let ") else { return nil }
                let rest = trimmed.dropFirst("static let ".count)
                // `all` is a collection, not a symbol: it is the index the
                // resolve-and-distinct tests iterate, so including it here would
                // require a view to reference `Symbols.all` and it never does.
                if rest.hasPrefix("all:") { return nil }
                let name = rest.prefix { $0.isLetter || $0.isNumber || $0 == "_" }
                return name.isEmpty ? nil : String(name)
            }
    }

    /// The names in `Symbols.all`, read from the same source.
    private static let constants: Set<String> = {
        guard let text = try? String(
            contentsOf: repositoryRoot.appendingPathComponent("NepalKit/Symbols.swift"),
            encoding: .utf8
        ),
              let start = text.range(of: "static let all: [String] = ["),
              let end = text.range(of: "]", range: start.upperBound ..< text.endIndex)
        else { return [] }
        return Set(
            text[start.upperBound ..< end.lowerBound]
                .split(separator: ",")
                .compactMap { entry -> String? in
                    let name = entry.trimmingCharacters(in: .whitespacesAndNewlines)
                    return name.isEmpty ? nil : name
                }
        )
    }()

    /// The repository root, found by searching upward for the project file.
    ///
    /// Hop-counting is what broke twice here. This test compiles through the
    /// harness at `scripts/apptests/Tests/NepalKitTests/`, and `#filePath` is
    /// that symlinked path at run time, so two `deletingLastPathComponent` calls
    /// land in `Tests/` rather than the repository root — and `standardizedFileURL`
    /// does not help either, because Swift records the path the compiler was
    /// given. Searching upward from either form until the project file appears
    /// cannot depend on which one is in effect.
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
}
