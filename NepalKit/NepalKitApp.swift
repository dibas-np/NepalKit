// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Dibas Sigdel
import AppKit
import AppIntents
import NepalKitCore
import SwiftUI

@main
struct NepalKitApp: App {
    @State private var settingsModel: DisplaySettingsModel
    @State private var menuBarModel: MenuBarModel
    @State private var clockModel: ClockModel
    @State private var converterModel: ConverterModel
    @State private var monthGridModel: MonthGridModel
    @State private var loginItemModel: LoginItemModel
    @State private var updateCheckModel: UpdateCheckModel
    @State private var metadataCache = DeferredAppMetadata()

    init() {
        NepalKitShortcuts.updateAppShortcutParameters()
        let settings = DisplaySettingsModel()
        let reference = settings.timeReference
        let menuBar = MenuBarModel(store: SettingsStore(), timeZone: reference.timeZone)
        let clock = ClockModel(timeReference: reference)
        let monthGrid = MonthGridModel(timeZone: reference.timeZone)
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
        let login = LoginItemModel()
        login.ensureDefaultOn()
        _loginItemModel = State(initialValue: login)
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
            MenuBarLabel(menuBar: menuBarModel, settings: settingsModel, updates: updateCheckModel)
        }
        .menuBarExtraStyle(.window)
        .commands {
            CommandGroup(replacing: .appTermination) {
                Button(Strings.quitLabel, action: AppTermination.quit)
                    .keyboardShortcut("q")
            }
        }
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
