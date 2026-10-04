// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Dibas Sigdel
import AppKit
import AppIntents
import NepalKitCore
import SwiftUI

@main
struct NepalKitApp: App {
    @State private var settingsModel = DisplaySettingsModel()
    @State private var menuBarModel = MenuBarModel()
    @State private var clockModel = ClockModel()
    @State private var converterModel = ConverterModel()
    /// No default initializer: the default-on registration below must run
    /// before the model is ever read, and a property initializer would run
    /// first, constructing a second model that is immediately discarded.
    @State private var loginItemModel: LoginItemModel
    /// The updater owns its start: it is constructed and started in `init`, at
    /// launch, because starting it is what schedules the automatic background
    /// check — a user who never opens Settings still gets one. The feed URL and
    /// the public key are pinned in Info.plist (ADR-0012); the wiring lives here
    /// because this is the only place that outlives every surface.
    @State private var updateCheckModel: UpdateCheckModel
    /// Owned here rather than in `SettingsView` so the cache outlives every
    /// presentation of the window: without it, each reopen would re-read the
    /// bundled LICENSE.
    @State private var metadataCache = DeferredAppMetadata()

    init() {
        // App Shortcuts registration: the documented push telling the App
        // Intents framework these shortcuts exist (wayfinder ticket 01,
        // finding 1.9). Parameterless shortcuts are said to register on
        // install alone, but observation showed the Shortcuts database stayed
        // empty until this call ran at launch — one of the prototype's
        // findings, and the reason it lives in init: every launch re-asserts
        // the registration, cold or warm.
        NepalKitShortcuts.updateAppShortcutParameters()
        // Default on: the date is in the menu bar from the moment of sign-in.
        // Configured through a local so init never touches wrapper storage.
        let login = LoginItemModel()
        login.ensureDefaultOn()
        _loginItemModel = State(initialValue: login)
        // `startingUpdater: false` so the explicit start below is the one owner
        // of "when the updater begins", rather than the controller starting it
        // mid-initialisation. A failed start records an outcome, so Settings
        // says "could not check" instead of silently never checking.
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
                dataset: AppData.dataset,
                // The same instance Settings reads, so an update found while the
                // popover is open puts the footer's button on screen immediately.
                updates: updateCheckModel
            )
        } label: {
            // The shown label stays the short date, prefixed only while an update
            // is unattended; the announcement is a sentence that names the app
            // and pronounces the date. Merging them would put "NepalKit," in the
            // menu bar itself.
            Text(menuBarModel.title(
                settings: settingsModel.settings,
                updateAvailable: updateCheckModel.isShowingReminder
            ))
                .accessibilityLabel(menuBarModel.spokenTitle(
                    settings: settingsModel.settings,
                    updateAvailable: updateCheckModel.isShowingReminder
                ))
        }
        .menuBarExtraStyle(.window)
        // A menu-bar-only app has no Dock icon and no Cmd-Tab presence, so this
        // is the normal exit path. The shortcut is registered here on the
        // termination command group, NOT on the popover's Quit button: a
        // button-local keyboardShortcut only fires while the popover holds
        // focus, and an LSUIElement app is frequently not frontmost, so that
        // would not be an exit path at all. One registration, one action.
        //
        // It is registered on the app's command group rather than anywhere in
        // Settings precisely so it keeps working with the Settings window open
        // and frontmost — a shortcut scoped to the popover would not.
        .commands {
            CommandGroup(replacing: .appTermination) {
                Button(Strings.quitLabel, action: AppTermination.quit)
                    .keyboardShortcut("q")
            }
        }
        // The native Settings scene (ADR-0011). Declaring it is the easy half;
        // reaching it from a menu-bar-only app is the half that needed deciding,
        // and `WindowPresentation` is what makes it usable once open.
        //
        // About used to be a second scene, a `Window` with its own id. It is a tab
        // in here now, which is why this is the app's only window scene: the facts
        // a bug report needs are identity facts, and they sit in the sidebar footer
        // of the one window a user can reach, rather than behind a second window
        // they have to know exists. `AppMetadata` is threaded through
        // `DeferredAppMetadata` so the bundled LICENSE is still not read at launch
        // — see that type for why that is worth keeping.
        Settings {
            SettingsView(
                settings: settingsModel,
                loginItem: loginItemModel,
                updates: updateCheckModel,
                menuBar: menuBarModel,
                metadata: metadataCache.value,
                dataset: AppData.dataset
            )
        }
    }
}
