import SwiftUI
@_exported import NepalKitCore

@main
struct NepalKitApp: App {
    @State private var settingsModel = DisplaySettingsModel()

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
