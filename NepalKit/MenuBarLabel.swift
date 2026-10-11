// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Dibas Sigdel
import SwiftUI

/// The menu-bar item's label: the date in the user's menu-bar format, prefixed
/// only while an update is unattended. The announcement is a sentence that
/// names the app and pronounces the date; merging the two would put
/// "NepalKit," in the menu bar itself.
///
/// Its own view so that the menu-bar clock's tick invalidates this label and
/// nothing above it.
struct MenuBarLabel: View {
    let menuBar: MenuBarModel
    let settings: DisplaySettingsModel
    let updates: UpdateCheckModel

    var body: some View {
        Text(menuBar.title(settings: settings.settings, updateAvailable: updates.isShowingReminder))
            .accessibilityLabel(menuBar.spokenTitle(settings: settings.settings, updateAvailable: updates.isShowingReminder))
    }
}
