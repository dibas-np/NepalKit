// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Dibas Sigdel
import NepalKitCore
import SwiftUI

/// The "General" tab: what the app shows, and whether it starts at login.
///
/// Split out of `SettingsView` because that type is now the window — a system
/// `TabView` sidebar over three destinations — and these sections are one
/// destination among them. Keeping them in the window's own type would mean a
/// file holding a layout and unrelated forms.
///
/// Software update is not here. It moved to the About tab, beside the version it
/// updates, so the updater is no longer split across two destinations.
struct GeneralSettingsView: View {
    @Bindable var settings: DisplaySettingsModel
    @Bindable var loginItem: LoginItemModel
    /// The same dataset the rest of the app converts with (ADR-0010), so the
    /// Display section's live preview renders the calendar the app actually uses.
    let dataset: CalendarDataset

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

                if let preview = DisplayPreview.todayText(now: .now, in: dataset, settings: settings.settings) {
                    // The example is the section's payoff: both pickers above
                    // change every date the app renders, and this row is one of
                    // those dates, re-rendered as the pickers flip so the choice
                    // lands where it is made rather than only in the menu bar.
                    // Re-reads `settings.settings` in `body`, so the preview is
                    // live without any explicit wiring.
                    LabeledContent(Strings.displayPreviewLabel) {
                        Text(preview)
                    }
                    .accessibilityElement(children: .combine)
                }
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
#Preview("General tab") {
    GeneralSettingsView(
        settings: .preview,
        loginItem: LoginItemModel(service: PreviewLoginService()),
        dataset: AppData.dataset
    )
    .frame(width: 460)
}
#endif
