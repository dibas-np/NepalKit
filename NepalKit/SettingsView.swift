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
    let settings: DisplaySettingsModel
    let loginItem: LoginItemModel
    /// Optional because the update surface cannot exist before an updater is
    /// configured, which needs a published feed and a signing key. Absent, the
    /// section is omitted rather than shown disabled, so no build ever
    /// advertises a control that cannot work.
    let updates: UpdateCheckModel?

    var body: some View {
        Form {
            Section(Strings.displaySection) {
                Picker(Strings.digitScriptLabel, selection: Binding(
                    get: { settings.settings.digits },
                    set: { settings.save(digits: $0) }
                )) {
                    Text(Strings.digitsLatin).tag(DigitScript.latin)
                    Text(Strings.digitsDevanagari).tag(DigitScript.devanagari)
                }
                .pickerStyle(.segmented)

                Picker(Strings.monthNameLabel, selection: Binding(
                    get: { settings.settings.monthNames },
                    set: { settings.save(monthNames: $0) }
                )) {
                    Text(Strings.monthsNepali).tag(MonthNameStyle.nepali)
                    Text(Strings.monthsTransliterated).tag(MonthNameStyle.transliterated)
                }
                .pickerStyle(.segmented)
            }

            Section(Strings.startupSection) {
                Toggle(isOn: Binding(
                    get: { loginItem.isOn },
                    set: { loginItem.setOn($0) }
                )) {
                    Label(Strings.launchAtLoginLabel, systemImage: Symbols.launchAtLogin)
                        .symbolRenderingMode(.monochrome)
                }
            }

            if let updates {
                Section(Strings.updatesSection) {
                    Button(Strings.checkForUpdatesLabel, action: updates.checkNow)

                    Toggle(isOn: Binding(
                        get: { updates.automaticallyChecks },
                        set: { updates.automaticallyChecks = $0 }
                    )) {
                        Text(Strings.updateAutomaticallyLabel)
                    }

                    if let status = updates.statusText {
                        Text(status)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 460)
    }
}
