import SwiftUI
import NepalKitCore

/// Popover shell: today's dates plus the display settings section.
/// Converter arrives in a later ticket.
struct PopoverView: View {
    let model: DisplaySettingsModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let today = todayBS(now: Date(), in: .v1) {
                Text(format(today, settings: model.settings))
                Text(gregorianReference())
                    .foregroundStyle(.secondary)
            } else {
                Text(Strings.dateUnavailable)
            }
        }
        .padding()
        .frame(minWidth: 220)
        Divider()
        SettingsSection(model: model)
            .padding(.top, 4)
    }

    private static let gregorianFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .none
        formatter.timeZone = nepalTimeZone
        return formatter
    }()

    private func gregorianReference() -> String {
        Self.gregorianFormatter.string(from: Date())
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
}

#Preview {
    PopoverView(model: DisplaySettingsModel())
}
