// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Dibas Sigdel
import SwiftUI

/// The bar along the bottom of the popover: Update (when available), Settings and Quit.
struct PopoverFooter: View {
    let openSettings: () -> Void
    let updates: UpdateCheckModel

    var body: some View {
        // One glass container for all the buttons: glass can't sample other glass,
        // so buttons in separate containers render inconsistently.
        GlassEffectContainer(spacing: 8) {
            VStack(spacing: 0) {
                Divider()
                HStack(spacing: 8) {
                    Spacer(minLength: 8)

                    // Hidden rather than disabled when there is nothing to install.
                    if updates.isUpdateAvailable {
                        updateButton
                    }

                    settingsButton
                    quitButton
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }
        }
    }

    /// Update, shown only while an update is available. Runs the same `checkNow`
    /// as Settings so Sparkle presents its own install flow.
    private var updateButton: some View {
        Button(Strings.updateButtonLabel, systemImage: Symbols.update, action: updates.checkNow)
            .buttonStyle(.glassProminent)
            .font(.caption)
            .symbolRenderingMode(.monochrome)
            .accessibilityLabel(Strings.updateButtonLabelSpoken)
            .accessibilityHint(Strings.updateButtonHelp)
    }

    /// Settings, as a bare gear.
    ///
    /// Icon only; `.iconOnly` keeps the title in the accessibility tree.
    private var settingsButton: some View {
        Button(Strings.settingsLabel, systemImage: Symbols.settings) {
            WindowPresentation.present(open: openSettings)
        }
        .labelStyle(.iconOnly)
        .buttonStyle(.glass)
        .font(.caption)
        .symbolRenderingMode(.monochrome)
        // The spoken label drops the visual ellipsis.
        .accessibilityLabel(Strings.settingsLabelSpoken)
        .accessibilityHint(Strings.settingsHelp)
    }

    /// Quit, as text: there is no conventional glyph for it. ⌘Q lives on the app's
    /// termination command group so it works without the popover open.
    private var quitButton: some View {
        Button(Strings.quitFooterLabel, action: AppTermination.quit)
            .buttonStyle(.glass)
            .font(.caption)
            .accessibilityElement(children: .combine)
            .accessibilityLabel(Strings.quitLabel)
            .accessibilityHint(Strings.quitHelp)
    }
}
