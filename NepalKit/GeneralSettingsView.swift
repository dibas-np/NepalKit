// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Dibas Sigdel
import NepalKitCore
import SwiftUI

/// The "General" tab: what the app shows, and whether it starts at login.
///
/// Split out of `SettingsView` because that type is now the window — a split view
/// with a sidebar and a tab switcher — and these two sections are one destination
/// among three. Keeping them in the window's own type would mean a file holding a
/// layout and two unrelated forms.
///
/// Software update is not here. It moved to the About tab, beside the version it
/// updates, so the updater is no longer split across two destinations.
struct GeneralSettingsView: View {
    @Bindable var settings: DisplaySettingsModel
    @Bindable var loginItem: LoginItemModel

    var body: some View {
        Form {
            Section(Strings.displaySection) {
                Picker(Strings.digitScriptLabel, selection: $settings.digits) {
                    // The en dash shows the range on screen, where it reads
                    // correctly; announced, it is unpredictable, so this option
                    // speaks a plain hyphen. Same split as the option below.
                    Text(Strings.digitsLatin)
                        .tag(DigitScript.latin)
                        .accessibilityLabel(Strings.digitsLatinSpoken)
                    Text(Strings.digitsDevanagari)
                        .tag(DigitScript.devanagari)
                        // The option announces with Latin digits so it stays
                        // identifiable aloud; the screen keeps the Devanagari
                        // characters it is describing.
                        .accessibilityLabel(Strings.digitsDevanagariSpoken)
                }
                .pickerStyle(.segmented)

                Picker(Strings.monthNameLabel, selection: $settings.monthNames) {
                    Text(Strings.monthsNepali).tag(MonthNameStyle.nepali)
                    Text(Strings.monthsTransliterated).tag(MonthNameStyle.transliterated)
                }
                .pickerStyle(.segmented)
            }

            Section(Strings.startupSection) {
                Toggle(isOn: $loginItem.launchAtLogin) {
                    Label(Strings.launchAtLoginLabel, systemImage: Symbols.launchAtLogin)
                        .symbolRenderingMode(.monochrome)
                }
                // The symbol is decoration beside a control that is already
                // named. Left in the label, some VoiceOver voices announce the
                // symbol name too ("power symbol button, launch at login, on"),
                // which is noise in front of the real name.
                .accessibilityLabel(Strings.launchAtLoginLabel)

                if let failure = loginItem.setupError {
                    // A failed register/unregister is invisible on the toggle:
                    // `isOn` follows the system, so it springs back without
                    // ever saying why. This line is where the reason lands.
                    Text(Strings.loginItemFailureReason(failure))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            Section(Strings.siriShortcutsSection) {
                // The sentence comes first and states what works, not what the
                // feature set suggests. Voice parameter-filling for the two
                // conversions is an OS behaviour — macOS 26 routes the
                // invocation and then cannot fill the parameters from speech —
                // while the same App Intents are fully usable from Shortcuts. A
                // section that implied the voice path worked would send people
                // to an answer of "late June or early July" from a web search.
                Text(Strings.siriShortcutsSummary)
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                ForEach(Strings.siriShortcutCapabilities) { capability in
                    VStack(alignment: .leading) {
                        Text(capability.title)
                            .font(.callout)
                        Text(capability.phrase)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            // Phrases are spoken, so they are taught as text
                            // rather than run: `SiriTipView` does not exist on
                            // macOS. Read as one string with the capability
                            // named, because a bare phrase announced on its own
                            // does not say what it does.
                            .accessibilityLabel(capability.spokenDescription)
                    }
                }
            }
        }
        .formStyle(.grouped)
    }
}

#if DEBUG
/// Preview stand-in so the canvas renders without the login-item service or
/// persistence side effects. Nothing else may use this: the production seam lives
/// in NepalKitApp, and a mock that leaked past #if DEBUG would silently replace
/// the real service. It stays nonisolated because `LoginItemServicing` is
/// nonisolated, and a MainActor conformance only satisfies that protocol where
/// default isolation agrees.
private final class PreviewLoginService: LoginItemServicing {
    var isRegistered = true
    func register() throws {}
    func unregister() throws {}
}

#Preview("General tab") {
    GeneralSettingsView(
        settings: .preview,
        loginItem: LoginItemModel(service: PreviewLoginService())
    )
    .frame(width: 460)
}
#endif
