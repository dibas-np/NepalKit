import SwiftUI
import NepalKitCore

/// Popover: today details, converter, and display settings.
struct PopoverView: View {
    let settings: DisplaySettingsModel
    let clock: ClockModel
    let converter: ConverterModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
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
                    Text("\(Strings.nepalTimeLabel): \(clock.nptTimeString(digits: settings.settings.digits))")
                    Text("\(Strings.localTimeLabel): \(clock.localTimeString(digits: settings.settings.digits))")
                        .foregroundStyle(.secondary)
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
        ConverterView(model: converter, settings: settings.settings)
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
    static let monthsTransliterated = "English"
    static let nepalTimeLabel = "Nepal Time"
    static let localTimeLabel = "Local"
    static let converterLabel = "Converter"
    static let bsToAD = "BS → AD"
    static let adToBS = "AD → BS"
    static let yearLabel = "Year"
    static let monthLabel = "Month"
    static let dayLabel = "Day"
    static let converterOutOfRange = "Outside supported range"
}

#Preview {
    PopoverView(settings: DisplaySettingsModel(), clock: ClockModel(), converter: ConverterModel())
}
