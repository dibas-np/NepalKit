import SwiftUI

@main
struct NepalKitApp: App {
    @State private var settingsModel = DisplaySettingsModel()
    @State private var menuBarModel = MenuBarModel()
    @State private var clockModel = ClockModel()
    @State private var converterModel = ConverterModel()

    var body: some Scene {
        MenuBarExtra {
            PopoverView(settings: settingsModel, clock: clockModel, converter: converterModel)
        } label: {
            Text(menuBarModel.title(settings: settingsModel.settings))
        }
        .menuBarExtraStyle(.window)
    }
}
