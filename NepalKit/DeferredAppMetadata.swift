// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Dibas Sigdel
import AppKit

/// `AppMetadata.current()` on first use, then cached.
///
/// `AppMetadata.current()` reads the bundled 35 KB LICENSE and asks AppKit for
/// the app icon. Neither is cheap, and the Settings window's sidebar footer needs
/// metadata on every redraw while nothing about it changes.
///
/// The deferral is not incidental. A scene's content closure is evaluated at
/// launch even for a window that is never opened, so constructing `AppMetadata`
/// there would pay for the LICENSE read on every launch — for a window most
/// sessions never show. Holding the cache and touching `value` from a view's body
/// moves the cost to the first time the window is actually presented.
///
/// So `SettingsView` is handed this cache, never its value, and reads `value`
/// only in its body. The scene builder still constructs `SettingsView` at
/// launch, but that no longer touches the cache. That `SettingsView.body` is not
/// evaluated at launch was observed once, with a print in that body and a
/// positive control in the menu-bar label; no test guards it.
@MainActor
final class DeferredAppMetadata {
    private var cached: AppMetadata?

    var value: AppMetadata {
        if let cached { return cached }
        let fresh = AppMetadata.current()
        cached = fresh
        return fresh
    }
}
