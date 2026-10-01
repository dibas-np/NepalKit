// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Dibas Sigdel
import SwiftUI

/// The Settings window's destinations.
///
/// `CaseIterable` order is sidebar order, and it follows the platform's own
/// convention for a Settings window: the general preferences first, then the
/// app's feature surface, then what this build is. Identity is the enum itself
/// rather than the row index, so a future tab inserted in the middle keeps the
/// selection it had.
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

    /// The landing tab: General, where the settings a user came to change live.
    /// It is also the first case now, so opening Settings lands on the sidebar's
    /// first row either way. Recorded here so the default stays a deliberate
    /// edit rather than an accident of enumeration.
    static let landingTab: SettingsTab = .general
}
