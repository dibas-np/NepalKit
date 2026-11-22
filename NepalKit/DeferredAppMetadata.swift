// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Dibas Sigdel
import AppKit

/// `AppMetadata.current()` on first use, then cached.
/// Deferred because a scene's content is built at launch even if its window never
/// opens; reading `value` only in `SettingsView.body` keeps the LICENSE read and
/// icon lookup off the launch path.
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
