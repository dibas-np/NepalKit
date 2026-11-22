// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Dibas Sigdel
import NepalKitCore
import SwiftUI

/// The Menu Bar tab: a live preview of the menu-bar item and its format options.
/// Digit script and month names stay in General because they affect the popover too.
struct MenuBarSettingsView: View {
    @Bindable var menuBar: MenuBarModel
    let settings: DisplaySettings
    let timeReference: TimeReference
    let updateAvailable: Bool

    var body: some View {
        Form {
            // Its own view so the clock's tick re-evaluates only the preview.
            MenuBarPreview(menuBar: menuBar, settings: settings, updateAvailable: updateAvailable)
            Section {
                Toggle(Strings.menuBarShowsWeekday, isOn: $menuBar.showsWeekday)
                Toggle(Strings.menuBarShowsYear, isOn: $menuBar.showsYear)
                Toggle(Strings.menuBarShowsTime, isOn: $menuBar.showsTime)
                // Disabled rather than hidden while the time is off, as in the system clock's settings.
                Group {
                    Toggle(Strings.menuBarUsesTwentyFourHourClock, isOn: $menuBar.usesTwentyFourHourClock)
                    Toggle(Strings.menuBarShowsSeconds, isOn: $menuBar.showsSeconds)
                }
                .padding(.leading)
                .disabled(!menuBar.showsTime)
            } header: {
                Text(Strings.menuBarFormatSection)
            } footer: {
                Text(Strings.menuBarTimeFootnote(timeReference))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }
}

/// The Menu Bar tab's preview: what the menu-bar item shows and how it is
/// announced.
private struct MenuBarPreview: View {
    let menuBar: MenuBarModel
    let settings: DisplaySettings
    let updateAvailable: Bool

    var body: some View {
        Section {
            // Glass on the value itself: a grouped `Form` section paints over anything
            // behind it, so `.glassEffect` on the window was invisible (and swallowed clicks).
            Text(preview)
                .font(.body.monospacedDigit())
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .glassEffect(.regular, in: .rect(cornerRadius: 8))
                .accessibilityLabel(Strings.menuBarPreviewCaption)
                .accessibilityValue(preview)
        } header: {
            Text(Strings.menuBarPreviewCaption)
        } footer: {
            Text(spokenPreview)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private var preview: String {
        menuBar.title(
            settings: settings,
            in: AppData.dataset,
            updateAvailable: updateAvailable
        )
    }

    /// Reuses `spokenTitle` so the preview cannot drift from what the menu bar announces.
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
        timeReference: .nepal,
        updateAvailable: false
    )
    .frame(width: 460)
}
#endif
