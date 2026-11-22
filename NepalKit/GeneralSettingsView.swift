// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Dibas Sigdel
import NepalKitCore
import SwiftUI

/// The General tab: display options, time zone, login item and Siri shortcuts.
struct GeneralSettingsView: View {
    @Bindable var settings: DisplaySettingsModel
    @Bindable var loginItem: LoginItemModel
    let dataset: CalendarDataset
    /// From the environment so the label redraws when the zone or locale changes.
    @Environment(\.timeZone) private var timeZone
    @Environment(\.locale) private var locale

    var body: some View {
        Form {
            Section(Strings.displaySection) {
                Picker(Strings.digitScriptLabel, selection: $settings.digits) {
                    // Spoken with a plain hyphen; VoiceOver reads the en dash unpredictably.
                    Text(Strings.digitsLatin)
                        .tag(DigitScript.latin)
                        .accessibilityLabel(Strings.digitsLatinSpoken)
                    Text(Strings.digitsDevanagari)
                        .tag(DigitScript.devanagari)
                        // Announced with Latin digits so the option stays identifiable aloud.
                        .accessibilityLabel(Strings.digitsDevanagariSpoken)
                }
                .pickerStyle(.segmented)

                Picker(Strings.monthNameLabel, selection: $settings.monthNames) {
                    Text(Strings.monthsNepali).tag(MonthNameStyle.nepali)
                    Text(Strings.monthsTransliterated).tag(MonthNameStyle.transliterated)
                }
                .pickerStyle(.segmented)

                // Redrawn at each midnight in the chosen zone so it never shows yesterday.
                TimelineView(MidnightSchedule(timeZone: settings.timeZone)) { _ in
                    if let preview = DisplayPreview.todayText(
                        now: .now, timeZone: settings.timeZone, in: dataset, settings: settings.settings
                    ) {
                        LabeledContent(Strings.displayPreviewLabel) {
                            Text(preview)
                        }
                        .accessibilityElement(children: .combine)
                    }
                }
            }

            Section {
                Picker(Strings.timeZoneLabel, selection: $settings.timeReferenceSelection) {
                    Text(Strings.timeZoneNepal).tag(TimeReference.nepal)
                    Text(Strings.timeZoneLocal(zoneName: TimeReference.localZoneName(timeZone, locale: locale)))
                        .tag(TimeReference.local)
                }
            } header: {
                Text(Strings.timeZoneSection)
            } footer: {
                Text(Strings.timeZoneFootnote)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section(Strings.startupSection) {
                Toggle(isOn: $loginItem.launchAtLogin) {
                    Label(Strings.launchAtLoginLabel, systemImage: Symbols.launchAtLogin)
                        .symbolRenderingMode(.monochrome)
                }
                // Named without the symbol, which some voices would otherwise announce.
                .accessibilityLabel(Strings.launchAtLoginLabel)

                if loginItem.requiresApproval {
                    Text(Strings.loginItemNeedsApproval)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Button(Strings.openLoginItemsSettings) {
                        loginItem.openLoginItemsSettings()
                    }
                }

                if let failure = loginItem.setupError {
                    // The toggle springs back on failure without saying why; this line does.
                    Text(Strings.loginItemFailureReason(failure))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            Section(Strings.siriShortcutsSection) {
                // Voice parameter-filling for the conversions doesn't work on macOS 26,
                // so the summary states what does: the same intents from Shortcuts.
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
                            // `SiriTipView` does not exist on macOS, so phrases are shown as text and
                            // read together with the capability they invoke.
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
