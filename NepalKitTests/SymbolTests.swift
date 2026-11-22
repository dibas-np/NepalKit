// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Dibas Sigdel
import AppKit
import Testing
@testable import NepalKit

/// An unresolvable SF Symbol name renders as nothing, with no error, so these
/// tests make a typo fail the suite.
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
        // Two names for one glyph would lose the distinction they exist to make.
        #expect(Set(Symbols.all).count == Symbols.all.count)
    }

    @Test func everySymbolIsReachableFromTheApp() throws {
        // A name no view renders still passes the other tests. Sources are read
        // from disk because SwiftUI leaves nothing to inspect at runtime, and
        // matched on the constant name, since views write `Symbols.name`.
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

    /// Constants declared on `Symbols`, parsed from its source.
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
                // `all` is the index of symbols, not a symbol.
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

    /// Searched upward because `#filePath` may be the symlinked harness path.
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
