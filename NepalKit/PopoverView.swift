import SwiftUI
import NepalKitCore

/// Popover shell: today's dates. Converter and Settings sections arrive in later tickets.
struct PopoverView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let today = todayBS(now: Date(), in: .sample) {
                Text(format(today, digits: .latin, monthNames: .transliterated))
                Text(format(today, digits: .devanagari, monthNames: .nepali))
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
        return formatter
    }()

    private func gregorianTitle(for date: Date) -> String {
        Self.gregorianFormatter.string(from: date)
    }
}

#Preview {
    PopoverView()
}
