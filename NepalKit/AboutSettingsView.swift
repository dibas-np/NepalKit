// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Dibas Sigdel
import NepalKitCore
import SwiftUI

struct AboutSettingsView: View {
    @Bindable var updates: UpdateCheckModel
    let metadata: AppMetadata
    let dataset: CalendarDataset

    var body: some View {
        Form {
            Section {
                LabeledContent(Strings.versionLabel(metadata.versionDescription)) {
                    Text(Strings.aboutCurrentBuild)
                        .foregroundStyle(.secondary)
                }
                LabeledContent(Strings.datasetVersionLabel) {
                    Text(dataset.version)
                        .monospacedDigit()
                }
                LabeledContent(Strings.supportedRangeLabel) {
                    Text(Strings.supportedRange(dataset.supportedRange))
                        .monospacedDigit()
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel(Strings.supportedRangeLabel)
                .accessibilityValue(Strings.supportedRangeSpoken(dataset.supportedRange))
                if let note = Strings.provisionalYearsNote(dataset.provisionalYears) {
                    Text(note)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text(metadata.name)
            }

            Section(Strings.updatesSection) {
                Button(Strings.checkForUpdatesLabel, action: updates.checkNow)
                    .accessibilityLabel(Strings.checkForUpdatesLabelSpoken)

                Toggle(isOn: $updates.automaticChecksSetting) {
                    Text(Strings.updateAutomaticallyLabel)
                }

                Text(updates.statusText)
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                if let lastCheck = updates.lastCheckDate {
                    Text(Strings.updateLastChecked(lastCheck.formatted(date: .abbreviated, time: .shortened)))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
    }
}

#if DEBUG
#Preview("About tab") {
    AboutSettingsView(
        updates: UpdateCheckModel(service: PreviewUpdateService()),
        metadata: .current(),
        dataset: AppData.dataset
    )
    .frame(width: 460)
}
#endif
