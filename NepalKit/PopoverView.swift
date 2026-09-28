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

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(Strings.todayLabel, systemImage: "calendar")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .symbolRenderingMode(.hierarchical)
            if let bs = clock.bsString(settings: settings.settings),
               let gregorian = clock.gregorianString(settings: settings.settings)
            {
                Text(bs)
                    .font(.headline)
                HStack(spacing: 4) {
                    Text(gregorian)
                    if let weekday = clock.weekdayString(style: settings.settings.monthNames) {
                        Text("· \(weekday)")
                    }
                }
                .foregroundStyle(.secondary)
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
            } else {
                Text(Strings.dateUnavailable)
            }
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

/// User-facing strings in one place. Not a localization system: the app ships
/// one UI language (the month-name language setting is a date-presentation
/// setting, not a second UI language).
enum Strings {
    static let dateUnavailable = "Date unavailable"
    static let digitScriptLabel = "Digits"
    static let digitsLatin = "Latin 0–9"
    static let digitsDevanagari = "Devanagari ०–९"
    static let monthNameLabel = "Month names"
    static let monthsNepali = "Nepali"
    static let monthsTransliterated = "Transliterated"
    static let nepalTimeLabel = "Nepal Time"
    static let localTimeLabel = "Local"
    static let todayLabel = "Today"
    static let launchAtLoginLabel = "Launch at login"
    static let converterLabel = "Converter"
    static let bsToAD = "Bikram Sambat → Gregorian"
    static let adToBS = "Gregorian → Bikram Sambat"
    static let yearLabel = "Year"
    static let monthLabel = "Month"
    static let dayLabel = "Day"
    static let converterOutOfRange = "Outside supported range"
}

#Preview {
    PopoverView(settings: DisplaySettingsModel(), clock: ClockModel(), converter: ConverterModel(), loginItem: LoginItemModel())
}
