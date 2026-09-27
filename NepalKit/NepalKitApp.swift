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

/// Stored display settings shared by the menu-bar extra and the popover.
/// Settings UI arrives in a later ticket; until then the stored values (if any)
/// are read directly, defaulting to Latin digits and transliterated month names.
func resolveDisplaySettings() -> DisplaySettings {
    let digits = DigitScript(rawValue: UserDefaults.standard.string(forKey: "digitScript") ?? "") ?? .latin
    let monthNames = MonthNameStyle(rawValue: UserDefaults.standard.string(forKey: "monthNameStyle") ?? "") ?? .transliterated
    return DisplaySettings(digits: digits, monthNames: monthNames)
}

/// Short BS date for the menu-bar extra, honoring the stored display settings.
func menuBarTitle(now: Date) -> String {
    guard let today = todayBS(now: now, in: .v1) else { return "—" }
    return formatShort(today, settings: resolveDisplaySettings())
}
