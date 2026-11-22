// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Dibas Sigdel
import AppKit
import AppIntents
import NepalKitCore
import SwiftUI

@main
struct NepalKitApp: App {
    /// Built in `init` so the models that read today follow the settings model's
    /// time reference.
    @State private var settingsModel: DisplaySettingsModel
    @State private var menuBarModel: MenuBarModel
    @State private var clockModel: ClockModel
    @State private var converterModel: ConverterModel
    @State private var monthGridModel: MonthGridModel
    /// Built in `init` so the default-on registration runs before it is read.
    @State private var loginItemModel: LoginItemModel
    /// Started at launch so the background check runs without Settings ever opening.
    /// The feed URL and public key are pinned in Info.plist.
    @State private var updateCheckModel: UpdateCheckModel
    /// Owned here so the cached metadata outlives each Settings presentation.
    @State private var metadataCache = DeferredAppMetadata()

    init() {
        // Without this call at launch the Shortcuts database stayed empty, even for
        // parameterless shortcuts.
        NepalKitShortcuts.updateAppShortcutParameters()
        let settings = DisplaySettingsModel()
        let reference = settings.timeReference
        // The real store, explicitly: the model's default is in-memory, for tests.
        let menuBar = MenuBarModel(store: SettingsStore(), timeZone: reference.timeZone)
        let clock = ClockModel(timeReference: reference)
        let monthGrid = MonthGridModel(timeZone: reference.timeZone)
        // The converter only reads today for its starting day, so it doesn't follow changes.
        _converterModel = State(initialValue: ConverterModel(timeZone: reference.timeZone))
        settings.observeTimeReference { [weak menuBar, weak clock, weak monthGrid] reference in
            menuBar?.setTimeZone(reference.timeZone)
            clock?.setTimeReference(reference)
            monthGrid?.setTimeZone(reference.timeZone, now: .now)
        }
        _settingsModel = State(initialValue: settings)
        _menuBarModel = State(initialValue: menuBar)
        _clockModel = State(initialValue: clock)
        _monthGridModel = State(initialValue: monthGrid)
        // Configured through a local so init never touches wrapper storage.
        let login = LoginItemModel()
        login.ensureDefaultOn()
        _loginItemModel = State(initialValue: login)
        // Started explicitly so a failed start records an outcome Settings can show.
        let updates = UpdateCheckModel(service: SparkleUpdateService(startingUpdater: false))
        updates.start()
        _updateCheckModel = State(initialValue: updates)
    }

    var body: some Scene {
        MenuBarExtra {
            PopoverView(
                settings: settingsModel,
                clock: clockModel,
                converter: converterModel,
                monthGrid: monthGridModel,
                dataset: AppData.dataset,
                updates: updateCheckModel
            )
        } label: {
            // A separate view so the menu-bar clock's tick doesn't re-evaluate the App body.
            MenuBarLabel(menuBar: menuBarModel, settings: settingsModel, updates: updateCheckModel)
        }
        .menuBarExtraStyle(.window)
        // ⌘Q lives on the termination command group, not the popover's Quit button: an
        // LSUIElement app is often not frontmost, so a button-local shortcut rarely fires.
        .commands {
            CommandGroup(replacing: .appTermination) {
                Button(Strings.quitLabel, action: AppTermination.quit)
                    .keyboardShortcut("q")
            }
        }
        // The native Settings scene; About is one of its tabs.
        Settings {
            SettingsView(
                settings: settingsModel,
                loginItem: loginItemModel,
                updates: updateCheckModel,
                menuBar: menuBarModel,
                metadataCache: metadataCache,
                dataset: AppData.dataset
            )
        }
    }
}
