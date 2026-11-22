// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Dibas Sigdel
import SwiftUI

struct PopoverFooter: View {
    let openSettings: () -> Void
    let updates: UpdateCheckModel

    var body: some View {
        GlassEffectContainer(spacing: 8) {
            VStack(spacing: 0) {
                Divider()
                HStack(spacing: 8) {
                    Spacer(minLength: 8)

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

    private var updateButton: some View {
        Button(Strings.updateButtonLabel, systemImage: Symbols.update.rawValue, action: updates.checkNow)
            .buttonStyle(.glassProminent)
            .font(.caption)
            .symbolRenderingMode(.monochrome)
            .accessibilityLabel(Strings.updateButtonLabelSpoken)
            .accessibilityHint(Strings.updateButtonHelp)
    }

    private var settingsButton: some View {
        Button(Strings.settingsLabel, systemImage: Symbols.settings.rawValue) {
            WindowPresentation.present(open: openSettings)
        }
        .labelStyle(.iconOnly)
        .buttonStyle(.glass)
        .font(.caption)
        .symbolRenderingMode(.monochrome)
        .accessibilityLabel(Strings.settingsLabelSpoken)
        .accessibilityHint(Strings.settingsHelp)
    }

    private var quitButton: some View {
        Button(Strings.quitFooterLabel, action: AppTermination.quit)
            .buttonStyle(.glass)
            .font(.caption)
            .accessibilityElement(children: .combine)
            .accessibilityLabel(Strings.quitLabel)
            .accessibilityHint(Strings.quitHelp)
    }
}
