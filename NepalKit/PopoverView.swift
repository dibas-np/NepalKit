import SwiftUI
import NepalKitCore

/// Popover shell: today's dates plus the display settings section.
/// Converter arrives in a later ticket.
struct PopoverView: View {
    @Bindable var model: DisplaySettingsModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let today = todayBS(now: Date(), in: .v1) {
                Text(format(today, settings: model.settings))
                Text(gregorianTitle(for: Date()))
                    .foregroundStyle(.secondary)
            } else {
                Text("Date unavailable")
            }
            Divider()
            settingsSection
        }
        .padding()
        .frame(minWidth: 220)
    }

    private var settingsSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Picker("Digits", selection: digitBinding) {
                Text("Latin 0–9").tag(DigitScript.latin)
                Text("Devanagari ०–९").tag(DigitScript.devanagari)
            }
            .pickerStyle(.segmented)
            Picker("Month names", selection: monthNameBinding) {
                Text("Nepali").tag(MonthNameStyle.nepali)
                Text("English").tag(MonthNameStyle.transliterated)
            }
            .pickerStyle(.segmented)
        }
    }

    private var digitBinding: Binding<DigitScript> {
        Binding(get: { model.settings.digits }, set: { model.save(digits: $0) })
    }

    private var monthNameBinding: Binding<MonthNameStyle> {
        Binding(get: { model.settings.monthNames }, set: { model.save(monthNames: $0) })
    }

    private static let gregorianFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .none
        // Same anchor as the BS date: the Gregorian day in Nepal Time,
        // so both labels always agree even near NPT midnight.
        formatter.timeZone = TimeZone(identifier: "Asia/Kathmandu")!
        return formatter
    }()

    private func gregorianTitle(for date: Date) -> String {
        Self.gregorianFormatter.string(from: date)
    }
}

#Preview {
    PopoverView(model: DisplaySettingsModel())
}
