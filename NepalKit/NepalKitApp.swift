import Combine
import SwiftUI
@_exported import NepalKitCore

/// Observable display settings: persisted through DisplaySettingsStore,
/// published so the menu-bar extra and popover refresh instantly on change.
@MainActor
final class DisplaySettingsModel: ObservableObject {
    @Published private(set) var settings: DisplaySettings

    private let store: DisplaySettingsStore

    init(store: DisplaySettingsStore = DisplaySettingsStore()) {
        self.store = store
        self.settings = store.settings
    }

    func save(_ settings: DisplaySettings) {
        store.save(settings)
        self.settings = settings
    }

    func save(digits: DigitScript) {
        save(DisplaySettings(digits: digits, monthNames: settings.monthNames))
    }

    func save(monthNames: MonthNameStyle) {
        save(DisplaySettings(digits: settings.digits, monthNames: monthNames))
    }
}

@main
struct NepalKitApp: App {
    @StateObject private var settingsModel = DisplaySettingsModel()

    var body: some Scene {
        MenuBarExtra {
            PopoverView(model: settingsModel)
        } label: {
            TimelineView(.everyMinute) { _ in
                Text(menuBarTitle(now: Date(), settings: settingsModel.settings))
            }
        }
        .menuBarExtraStyle(.window)
    }
}

/// Short Bikram Sambat date for the menu-bar extra, honoring the given display settings.
func menuBarTitle(now: Date, settings: DisplaySettings) -> String {
    guard let today = todayBS(now: now, in: .v1) else { return "—" }
    return formatShort(today, settings: settings)
}
