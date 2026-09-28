import SwiftUI

@main
struct NepalKitApp: App {
    @State private var settingsModel = DisplaySettingsModel()
    @State private var menuBarModel = MenuBarModel()
    @State private var clockModel = ClockModel()
    @State private var converterModel = ConverterModel()
    @State private var loginItemModel = LoginItemModel()

    init() {
        // Default on: the date is in the menu bar from the moment of sign-in.
        // Configured through a local so init never touches wrapper storage.
        let login = LoginItemModel()
        login.ensureDefaultOn()
        _loginItemModel = State(initialValue: login)
    }

    var body: some Scene {
        MenuBarExtra {
            PopoverView(settings: settingsModel, clock: clockModel, converter: converterModel, loginItem: loginItemModel)
        } label: {
            Text(menuBarModel.title(settings: settingsModel.settings))
        }
        .menuBarExtraStyle(.window)
    }
}
