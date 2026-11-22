// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Dibas Sigdel
import NepalKitCore
import SwiftUI

struct GeneralSettingsView: View {
    @Bindable var settings: DisplaySettingsModel
    @Bindable var loginItem: LoginItemModel
    let dataset: CalendarDataset
    @Environment(\.timeZone) private var timeZone
    @Environment(\.locale) private var locale

    var body: some View {
        Form {
            Section(Strings.displaySection) {
                Picker(Strings.digitScriptLabel, selection: $settings.digits) {
                    Text(Strings.digitsLatin)
                        .tag(DigitScript.latin)
                        .accessibilityLabel(Strings.digitsLatinSpoken)
                    Text(Strings.digitsDevanagari)
                        .tag(DigitScript.devanagari)
                        .accessibilityLabel(Strings.digitsDevanagariSpoken)
                }
                .pickerStyle(.segmented)

                Picker(Strings.monthNameLabel, selection: $settings.monthNames) {
                    Text(Strings.monthsNepali).tag(MonthNameStyle.nepali)
                    Text(Strings.monthsTransliterated).tag(MonthNameStyle.transliterated)
                }
                .pickerStyle(.segmented)

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
                    Text(Strings.loginItemFailureReason(failure))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            Section(Strings.siriShortcutsSection) {
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
