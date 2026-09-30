// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Dibas Sigdel
import NepalKitCore
import SwiftUI

/// The native Settings surface.
///
/// This relocates the controls that were inline in the popover; it adds no new
/// setting. The models passed in are the same ones the popover already read, so
/// there is exactly one source of truth and no value is writable from two
/// places. Persistence stays in `SettingsStore` keyed by bundle identifier, so
/// settings survive relaunch and updates.
///
/// Control types are carried over unchanged from the popover deliberately: a
/// user who knows the segmented pickers should not have to relearn them.
/// Gregorian month names stay English — the month-name setting governs Bikram
/// Sambat and weekday names only, so a date may carry a Devanagari day and
/// year, an English Gregorian month name, and a weekday in either language at
/// once. That combination is intended (CONTEXT.md).
struct SettingsView: View {
    @Bindable var settings: DisplaySettingsModel
    @Bindable var loginItem: LoginItemModel
    /// The updater is constructed and started at launch (NepalKitApp), so the
    /// section always exists; it reads its outcome state from the same model
    /// the background check reports into.
    @Bindable var updates: UpdateCheckModel

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

            Section(Strings.updatesSection) {
                // The shown title keeps its ellipsis, which marks a control that
                // opens a sheet elsewhere. Spoken it is a pause and no meaning,
                // so the announcement drops it. No `.combine` is needed for the
                // label to win, exactly as for the launch-at-login control above.
                Button(Strings.checkForUpdatesLabel, action: updates.checkNow)
                    .accessibilityLabel(Strings.checkForUpdatesLabelSpoken)

                Toggle(isOn: $updates.automaticallyChecks) {
                    Text(Strings.updateAutomaticallyLabel)
                }

                if let status = updates.statusText {
                    // A plain Text already announces itself. Left
                    // unmodified rather than given a redundant label.
                    Text(status)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
        // A minimum for the same reason as About: pinned at 460 the window
        // clips at larger accessibility text sizes, and the segmented pickers
        // with translated labels are what overflow first.
        .frame(minWidth: 460)
    }
}

#if DEBUG
/// Preview stand-ins so the canvas renders without Sparkle, the login-item
/// service, or persistence side effects. Nothing else may use these: the
/// production seams live in NepalKitApp, and a mock that leaked past #if DEBUG
/// would silently replace the real services. `PreviewUpdateService` is
/// MainActor because `UpdateServicing` requires it; `PreviewLoginService` stays
/// nonisolated because `LoginItemServicing` is nonisolated, and a MainActor
/// conformance only satisfies that protocol where default isolation agrees.
@MainActor private final class PreviewUpdateService: UpdateServicing {
    var onOutcome: (@MainActor (UpdateOutcome) -> Void)?
    var onReminder: (@MainActor (Bool) -> Void)?
    var automaticallyChecksForUpdates = true
    func start() {}
    func checkForUpdates() {}
}

private final class PreviewLoginService: LoginItemServicing {
    var isRegistered = true
    func register() throws {}
    func unregister() throws {}
}

#Preview("Settings") {
    SettingsView(
        settings: .preview,
        loginItem: LoginItemModel(service: PreviewLoginService()),
        updates: UpdateCheckModel(service: PreviewUpdateService())
    )
    .frame(width: 460)
}
#endif
