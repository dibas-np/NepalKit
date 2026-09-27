import SwiftUI

@main
struct NepalKitApp: App {
    @State private var settingsModel = DisplaySettingsModel()
    @State private var menuBarModel = MenuBarModel()

    var body: some Scene {
        MenuBarExtra {
            PopoverView(model: settingsModel)
        } label: {
            Text(menuBarModel.title(settings: settingsModel.settings))
        }
        .menuBarExtraStyle(.window)
    }
}
