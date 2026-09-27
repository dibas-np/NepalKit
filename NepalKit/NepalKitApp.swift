import SwiftUI
import NepalKitCore

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
