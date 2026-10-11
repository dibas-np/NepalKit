// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Dibas Sigdel
import AppKit
import Testing
@testable import NepalKit

/// The Settings sidebar's rows: their order, and that each names itself and
/// draws its own symbol, so no two rows read or look alike.
@MainActor
struct SettingsTabTests {
    @Test func theSidebarLandsOnItsFirstRow() {
        #expect(SettingsTab.allCases == [.general, .menuBar, .about])
        #expect(SettingsTab.allCases.first == SettingsTab.landingTab)
        #expect(SettingsTab.allCases.map(\.id) == SettingsTab.allCases)
    }

    @Test func everyTabHasItsOwnTitleAndSymbol() {
        let tabs = SettingsTab.allCases
        #expect(tabs.map(\.title) == [Strings.generalTabTitle, Strings.menuBarTabTitle, Strings.aboutTabTitle])
        #expect(Set(tabs.map(\.symbol)).count == tabs.count)
        for tab in tabs {
            #expect(NSImage(systemSymbolName: tab.symbol, accessibilityDescription: nil) != nil, "\(tab) symbol")
        }
    }
}
