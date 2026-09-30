// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Dibas Sigdel
import SwiftUI

/// The Settings window's destinations.
///
/// `CaseIterable` order is sidebar order, and it is the order the tabs were
/// chosen in: what the menu bar does, then everything else, then what this build
/// is. Identity is the enum itself rather than the row index, so a future tab
/// inserted in the middle keeps the selection it had.
enum SettingsTab: String, CaseIterable, Identifiable {
    case menuBar
    case general
    case about

    var id: Self { self }

    var title: String {
        switch self {
        case .menuBar: Strings.menuBarTabTitle
        case .general: Strings.generalTabTitle
        case .about: Strings.aboutTabTitle
        }
    }

    var symbol: String {
        switch self {
        case .menuBar: Symbols.menuBar
        case .general: Symbols.general
        case .about: Symbols.about
        }
    }

    /// The landing tab.
    ///
    /// General, not the first case. Menu Bar is currently a read-only preview, so
    /// opening Settings onto it would land a user who came to change something on
    /// a page with nothing to change. When Menu Bar grows real controls the
    /// default can move; recorded here so that is a deliberate edit.
    static let landingTab: SettingsTab = .general
}
