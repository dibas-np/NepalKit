import SwiftUI
import NepalKitCore

/// Popover shell: today's dates. Converter and Settings sections arrive in later tickets.
struct PopoverView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let today = todayBS(now: Date(), in: .sample) {
                Text(format(today, settings: resolveDisplaySettings()))
                Text(gregorianTitle(for: Date()))
                    .foregroundStyle(.secondary)
            } else {
                Text("Date unavailable")
            }
        }
        .padding()
        .frame(minWidth: 220)
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
    PopoverView()
}
