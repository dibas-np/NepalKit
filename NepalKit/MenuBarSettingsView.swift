// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Dibas Sigdel
import NepalKitCore
import SwiftUI

/// The "Menu Bar" tab: what the menu-bar item currently shows, and the format
/// options that belong to it alone — weekday, year and Nepal Time clock, after
/// the macOS menu-bar clock's options.
///
/// Digit script and month names also shape the menu bar, but they shape the
/// popover too, so they stay in General where a user looking for "how do I
/// change my numbers" will find them.
///
/// The preview is kept above the options: it is where a toggle's effect is
/// seen, and it is also the thing a preview uniquely gives: the marker and the
/// beyond-range fallback are branches of `MenuBarModel.title` that are otherwise
/// unreachable until the day they matter, and a user who has never seen either
/// has no way to know what the menu bar will do. `MenuBarModelTests` covers the
/// logic; this shows the consequence.
struct MenuBarSettingsView: View {
    @Bindable var menuBar: MenuBarModel
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
            Section {
                Toggle(Strings.menuBarShowsWeekday, isOn: $menuBar.showsWeekday)
                Toggle(Strings.menuBarShowsYear, isOn: $menuBar.showsYear)
                Toggle(Strings.menuBarShowsTime, isOn: $menuBar.showsTime)
                // The clock's own options stay visible but disabled while the
                // time is off, as the system clock's settings do, so a user can
                // see they exist; indented to read as belonging to the toggle
                // above.
                Group {
                    Toggle(Strings.menuBarUsesTwentyFourHourClock, isOn: $menuBar.usesTwentyFourHourClock)
                    Toggle(Strings.menuBarShowsSeconds, isOn: $menuBar.showsSeconds)
                }
                .padding(.leading)
                .disabled(!menuBar.showsTime)
            } header: {
                Text(Strings.menuBarFormatSection)
            } footer: {
                Text(Strings.menuBarTimeFootnote)
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
