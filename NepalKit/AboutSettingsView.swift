// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Dibas Sigdel
import NepalKitCore
import SwiftUI

/// The "About" tab: what this build is, and how to keep it current.
///
/// Shows app and dataset versions, the supported calendar range,
/// and software update. Everything else this app could say about itself is
/// either already in the sidebar footer (name, icon, repository) or is prose that
/// belongs in the repository rather than in a preferences window.
///
/// Software update lives here rather than under General because both answers are
/// questions about *this build*: what it is, and how to get the next one. Grouping
/// them puts the version a user is about to report next to the control that
/// changes it, which is the pairing that makes a bug report actionable.
struct AboutSettingsView: View {
    @Bindable var updates: UpdateCheckModel
    /// The build's own facts. Read from the bundle by the app and passed in, so
    /// the version here cannot disagree with the one the menu bar was built from.
    let metadata: AppMetadata
    /// The same dataset the app converts with, so the range shown is the range the
    /// converter actually honours (ADR-0010).
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
            } header: {
                Text(metadata.name)
            }

            Section(Strings.updatesSection) {
                // The shown title keeps its ellipsis, which marks a control that
                // opens a sheet elsewhere. Spoken it is a pause and no meaning,
                // so the announcement drops it.
                Button(Strings.checkForUpdatesLabel, action: updates.checkNow)
                    .accessibilityLabel(Strings.checkForUpdatesLabelSpoken)

                Toggle(isOn: $updates.automaticallyChecks) {
                    Text(Strings.updateAutomaticallyLabel)
                }

                if let status = updates.statusText {
                    // A plain Text already announces itself. Left unmodified
                    // rather than given a redundant label.
                    Text(status)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                if let lastCheck = updates.lastCheckDate {
                    // Sits under the status because the two facts read as one
                    // sentence: current, as of when. Nil before the first
                    // check, matching the status line's own silence — an
                    // uncheckable claim is not stated here either.
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
/// The same stand-ins `GeneralSettingsView` uses. Duplicated rather than shared so
/// each preview block stays self-contained, which is the convention the file
/// headers in this module already follow.
@MainActor private final class AboutPreviewUpdateService: UpdateServicing {
    var onOutcome: (@MainActor (UpdateOutcome) -> Void)?
    var onReminder: (@MainActor (Bool) -> Void)?
    var automaticallyChecksForUpdates = true
    var lastCheckDate: Date?
    func start() {}
    func checkForUpdates() {}
}

#Preview("About tab") {
    AboutSettingsView(
        updates: UpdateCheckModel(service: AboutPreviewUpdateService()),
        metadata: .current(),
        dataset: AppData.dataset
    )
    .frame(width: 460)
}
#endif
