import AppKit
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
        // A menu-bar-only app has no Dock icon and no Cmd-Tab presence, so this
        // is the normal exit path. The shortcut is registered here on the
        // termination command group, NOT on the popover's Quit button: a
        // button-local keyboardShortcut only fires while the popover holds
        // focus, and an LSUIElement app is frequently not frontmost, so that
        // would not be an exit path at all. One registration, one action.
        .commands {
            CommandGroup(replacing: .appTermination) {
                Button(Strings.quitLabel, action: AppTermination.quit)
                    .keyboardShortcut("q")
            }
        }
    }
}
