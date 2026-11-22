// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Dibas Sigdel
import AppKit
import Testing
@testable import NepalKit

@MainActor
struct SymbolTests {
    @Test func everySymbolResolves() {
        for symbol in Symbols.allCases {
            #expect(
                NSImage(systemSymbolName: symbol.rawValue, accessibilityDescription: nil) != nil,
                "\(symbol.rawValue) does not resolve and would render as nothing"
            )
        }
    }

    @Test func everySymbolIsReachableFromTheApp() throws {
        let appDir = Repository.root.appendingPathComponent("NepalKit")
        let sources = try FileManager.default.contentsOfDirectory(atPath: appDir.path)
            .filter { $0.hasSuffix(".swift") && $0 != "Symbols.swift" }
            .map { try String(contentsOf: appDir.appendingPathComponent($0), encoding: .utf8) }
        #expect(!sources.isEmpty, "found no app sources at all — the path walk is broken")

        for symbol in Symbols.allCases {
            let use = "Symbols.\(symbol)"
            #expect(sources.contains { $0.contains(use) }, "\(use) is declared but no view references it")
        }
    }
}
