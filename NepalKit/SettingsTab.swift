// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Dibas Sigdel
import SwiftUI

enum SettingsTab: String, CaseIterable, Identifiable {
    case general
    case menuBar
    case about

    var id: Self { self }

    var title: String {
        switch self {
        case .general: Strings.generalTabTitle
        case .menuBar: Strings.menuBarTabTitle
        case .about: Strings.aboutTabTitle
        }
    }

    var symbol: String {
        switch self {
        case .general: Symbols.general
        case .menuBar: Symbols.menuBar
        case .about: Symbols.about
        }
    }

    static let landingTab: SettingsTab = .general
}
