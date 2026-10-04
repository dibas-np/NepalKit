// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Dibas Sigdel
#if DEBUG
import Foundation

/// Preview stand-in for the update framework, so a canvas renders without Sparkle,
/// a network, a published feed, or a signing key.
///
/// One type for both jobs rather than a copy beside each preview: three had
/// accumulated, and a mock is only trustworthy as the single thing you can be
/// sure is *not* the real service. `reporting:` is the only knob — omit it for
/// the resting state, pass an outcome to reach one a canvas cannot otherwise.
///
/// Behind `#if DEBUG` so a stand-in can never silently replace a real service in
/// a shipped build.
@MainActor
final class PreviewUpdateService: UpdateServicing {
    var automaticallyChecksForUpdates = true
    var lastCheckDate: Date?
    var onReminder: (@MainActor (Bool) -> Void)?

    /// Reports on assignment rather than in `init`, which runs before the model
    /// installs this closure, or in `start()`, which only `NepalKitApp` ever calls
    /// — so a stand-in reporting from `start()` never reports in a canvas, and the
    /// preview meant to show an available update renders the resting state.
    var onOutcome: (@MainActor (UpdateOutcome) -> Void)? {
        didSet { if let outcome { onOutcome?(outcome) } }
    }

    private let outcome: UpdateOutcome?

    init(reporting outcome: UpdateOutcome? = nil) {
        self.outcome = outcome
    }

    func start() {}
    func checkForUpdates() {}
}

/// Preview stand-in for the login-item service. The production seam lives in
/// NepalKitApp, and a mock that leaked past #if DEBUG would silently replace the
/// real service.
///
/// Nonisolated because `LoginItemServicing` is nonisolated, and a MainActor
/// conformance only satisfies that protocol where default isolation agrees.
final class PreviewLoginService: LoginItemServicing {
    var isRegistered = true
    func register() throws {}
    func unregister() throws {}
}
#endif
