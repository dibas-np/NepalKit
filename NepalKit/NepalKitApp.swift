// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Dibas Sigdel
import AppKit
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

    init() {
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
            PopoverView(settings: settingsModel, clock: clockModel, converter: converterModel, dataset: AppData.dataset)
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
        Settings {
            SettingsView(settings: settingsModel, loginItem: loginItemModel, updates: updateCheckModel)
        }
        // A single-instance named window rather than a `WindowGroup`, so repeated
        // About invocations focus the existing window instead of stacking
        // copies. The dataset is the same one the app converts with, so the
        // range line cannot drift from the conversion contract (ADR-0010).
        Window(Strings.aboutLabel, id: AboutWindow.id) {
            AboutScene(dataset: AppData.dataset)
        }
        .windowResizability(.contentSize)
    }
}

/// The About surface, and the reason its metadata is not read until now.
///
/// `Window`'s content closure is evaluated at launch even for a window that is
/// never opened, so `AppMetadata.current()` placed there reads the bundled
/// 35 KB LICENSE and asks AppKit for the app icon on every launch — paid for a
/// window most sessions never show. Moving the call into this view's `body`
/// defers it to the first time the window is actually presented, which is the
/// only point at which any of it is needed.
private struct AboutScene: View {
    let dataset: CalendarDataset
    @State private var deferred = DeferredAppMetadata()

    var body: some View {
        AboutView(metadata: deferred.value, dataset: dataset)
    }
}

/// `AppMetadata.current()` on first use, then cached.
///
/// A view is re-evaluated far more often than a window is opened, so the result
/// is held rather than re-read: without this the LICENSE would be parsed on
/// every redraw of the About window.
@MainActor
private final class DeferredAppMetadata {
    private var cached: AppMetadata?

    var value: AppMetadata {
        if let cached { return cached }
        let fresh = AppMetadata.current()
        cached = fresh
        return fresh
    }
}

#if DEBUG
#Preview("About scene") {
    AboutScene(dataset: AppData.dataset)
        .frame(width: 380)
}
#endif
