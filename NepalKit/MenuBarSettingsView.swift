// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Dibas Sigdel
import NepalKitCore
import SwiftUI

/// The "Menu Bar" tab: what the menu-bar item currently shows.
///
/// A preview rather than a control, and the honest reason is that nothing about
/// the menu bar is separately configurable yet. The two settings that shape it —
/// digit script and month names — also shape the popover, so they stay in General
/// where a user looking for "how do I change my numbers" will find them. Moving
/// them here would narrow the tab's name to a promise its own controls cannot
/// keep.
///
/// What this buys is the thing a preview uniquely gives: the marker and the
/// beyond-range fallback are branches of `MenuBarModel.title` that are otherwise
/// unreachable until the day they matter, and a user who has never seen either
/// has no way to know what the menu bar will do. `MenuBarModelTests` covers the
/// logic; this shows the consequence.
struct MenuBarSettingsView: View {
    let menuBar: MenuBarModel
    let settings: DisplaySettings
    /// The same flag the real menu-bar label reads, so the preview cannot disagree
    /// with the menu bar about whether an update is pending.
    let updateAvailable: Bool

    var body: some View {
        Form {
            Section {
                // Glass on the value itself, not on the form.
                //
                // Liquid Glass is only visible where nothing paints over it, and a
                // `Form(.grouped)` section paints its own background across the
                // full width. An earlier attempt put `.glassEffect` on the whole
                // window instead, where it was invisible for the same reason and
                // then swallowed clicks. The rule worth keeping: the material goes
                // on the control, never behind the chrome.
                Text(preview)
                    .font(.body.monospacedDigit())
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .glassEffect(.regular, in: .rect(cornerRadius: 8))
                    // The value is the point of the row, so it is not decoration.
                    .accessibilityLabel(Strings.menuBarPreviewCaption)
                    .accessibilityValue(preview)
            } header: {
                Text(Strings.menuBarPreviewCaption)
            } footer: {
                // Names what the spoken form is, since the value alone
                // ("12 Ashoj 2083") gives no clue it is a menu bar.
                Text(spokenPreview)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }

    /// The literal menu-bar string, through the same call the app makes.
    private var preview: String {
        menuBar.title(
            settings: settings,
            in: AppData.dataset,
            updateAvailable: updateAvailable
        )
    }

    /// The same value in the form the menu bar itself announces.
    ///
    /// Reuses `spokenTitle` rather than writing a second sentence, so the preview
    /// cannot drift from the menu bar the way a hand-written description of it
    /// eventually would.
    private var spokenPreview: String {
        menuBar.spokenTitle(
            settings: settings,
            in: AppData.dataset,
            updateAvailable: updateAvailable
        )
    }
}

#if DEBUG
#Preview("Menu Bar tab") {
    MenuBarSettingsView(
        menuBar: MenuBarModel(now: AppData.previewInstant, refreshes: false),
        settings: DisplaySettings(digits: .latin, monthNames: .transliterated),
        updateAvailable: false
    )
    .frame(width: 460)
}
#endif
