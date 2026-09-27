import SwiftUI
import NepalKitCore

@main
struct NepalKitApp: App {
    var body: some Scene {
        MenuBarExtra {
            PopoverView()
        } label: {
            TimelineView(.everyMinute) { _ in
                Text(menuBarTitle(now: Date()))
            }
        }
        .menuBarExtraStyle(.window)
    }
}

/// Short BS date for the menu-bar extra, honoring the stored display settings.
/// Settings UI arrives in a later ticket; until then the stored values (if any)
/// are read directly, defaulting to Latin digits and transliterated month names.
func menuBarTitle(now: Date) -> String {
    let digits = DigitScript(rawValue: UserDefaults.standard.string(forKey: "digitScript") ?? "") ?? .latin
    let monthNames = MonthNameStyle(rawValue: UserDefaults.standard.string(forKey: "monthNameStyle") ?? "") ?? .transliterated
    guard let today = todayBS(now: now, in: .sample) else { return "—" }
    return formatShort(today, digits: digits, monthNames: monthNames)
}
