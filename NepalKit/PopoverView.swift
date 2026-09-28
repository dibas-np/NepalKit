import AppKit
import SwiftUI
import NepalKitCore

/// Popover: today details, converter, launch-at-login, and display settings.
///
/// Iconography (per ADR-0004): SF Symbols everywhere in the popover, with the
/// rendering mode chosen per surface — hierarchical for section headers so the
/// symbols stay legible on translucent Liquid Glass in both appearances,
/// monochrome for small inline icons so they keep full contrast next to text.
/// The menu-bar extra itself stays date text only.
struct PopoverView: View {
    let settings: DisplaySettingsModel
    let clock: ClockModel
    let converter: ConverterModel
    let loginItem: LoginItemModel
    /// Injected so the year named in the range boundary state is the same
    /// dataset the rest of the view reads, and so a test can control it.
    var dataset: CalendarDataset = .v2

    /// Last Bikram Sambat year the bundled dataset can convert. Named in the
    /// range boundary state so a user past it can tell a data limit from a bug.
    private var lastSupportedBSYear: Int { dataset.supportedRange.upperBound }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(Strings.todayLabel, systemImage: "calendar")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .symbolRenderingMode(.hierarchical)
            if let bs = clock.bsString(settings: settings.settings, in: dataset) {
                Text(bs)
                    .font(.headline)
            } else {
                // Range boundary state: the bundled data has ended. Say so in
                // words rather than showing a blank, and keep the Gregorian date
                // and clocks below, which are still answerable.
                VStack(alignment: .leading, spacing: 2) {
                    Text(Strings.bsDateUnavailable)
                        .font(.headline)
                    Text(Strings.supportedThrough(lastSupportedBSYear, digits: settings.settings.digits))
                        .foregroundStyle(.secondary)
                }
            }
            if let gregorian = clock.gregorianString(settings: settings.settings) {
                HStack(spacing: 4) {
                    Text(gregorian)
                    if let weekday = clock.weekdayString(style: settings.settings.monthNames) {
                        Text("· \(weekday)")
                    }
                }
                .foregroundStyle(.secondary)
            }
            // Clocks sit outside the Gregorian conditional: they are answerable
            // regardless of calendar data, so they must survive the boundary.
            VStack(alignment: .leading, spacing: 2) {
                Label {
                    Text("\(Strings.nepalTimeLabel): \(clock.nptTimeString(digits: settings.settings.digits))")
                } icon: {
                    Image(systemName: "clock")
                        .symbolRenderingMode(.monochrome)
                }
                Label {
                    Text("\(Strings.localTimeLabel): \(clock.localTimeString(digits: settings.settings.digits))")
                        .foregroundStyle(.secondary)
                } icon: {
                    Image(systemName: "person")
                        .symbolRenderingMode(.monochrome)
                }
            }
            .monospacedDigit()
            .padding(.top, 2)
        }
        .padding()
        .frame(minWidth: 280)
        Divider()
        Label(Strings.converterLabel, systemImage: "arrow.left.arrow.right")
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .symbolRenderingMode(.monochrome)
            .padding(.horizontal)
        ConverterView(model: converter, settings: settings.settings)
            .padding(.horizontal)
        Divider()
        Toggle(isOn: Binding(
            get: { loginItem.isOn },
            set: { loginItem.setOn($0) }
        )) {
            Label(Strings.launchAtLoginLabel, systemImage: "power")
                .symbolRenderingMode(.monochrome)
        }
        .padding(.horizontal)
        Divider()
        SettingsSection(model: settings)
            .padding(.top, 4)
        Divider()
        // The visible exit path for a menu-bar-only app. The matching ⌘Q lives
        // on the app's termination command group (NepalKitApp.swift) so it works
        // when the app is frontmost without the popover open; this button is the
        // discoverable control for the same action.
        Button(Strings.quitLabel, action: AppTermination.quit)
            .padding(.horizontal)
            .padding(.bottom, 4)
    }
}

private struct SettingsSection: View {
    let model: DisplaySettingsModel

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Picker(Strings.digitScriptLabel, selection: Binding(
                get: { model.settings.digits },
                set: { model.save(digits: $0) }
            )) {
                Text(Strings.digitsLatin).tag(DigitScript.latin)
                Text(Strings.digitsDevanagari).tag(DigitScript.devanagari)
            }
            .pickerStyle(.segmented)

            Picker(Strings.monthNameLabel, selection: Binding(
                get: { model.settings.monthNames },
                set: { model.save(monthNames: $0) }
            )) {
                Text(Strings.monthsNepali).tag(MonthNameStyle.nepali)
                Text(Strings.monthsTransliterated).tag(MonthNameStyle.transliterated)
            }
            .pickerStyle(.segmented)
        }
    }
}
