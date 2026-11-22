// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Dibas Sigdel
import SwiftUI

/// The menu-bar item's label. A separate view so the clock's tick invalidates only
/// this label.
struct MenuBarLabel: View {
    let menuBar: MenuBarModel
    let settings: DisplaySettingsModel
    let updates: UpdateCheckModel

    var body: some View {
        Text(menuBar.title(settings: settings.settings, updateAvailable: updates.isShowingReminder))
            .accessibilityLabel(menuBar.spokenTitle(settings: settings.settings, updateAvailable: updates.isShowingReminder))
    }
}
