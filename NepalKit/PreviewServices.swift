// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Dibas Sigdel
#if DEBUG
import Foundation

/// Preview stand-in for the update framework. Pass `reporting:` to reach a state
/// a canvas cannot otherwise show.
@MainActor
final class PreviewUpdateService: UpdateServicing {
    var automaticallyChecksForUpdates = true
    var lastCheckDate: Date?
    var onReminder: (@MainActor (Bool) -> Void)?
    var onCycleFinished: (@MainActor () -> Void)?

    /// Reports on assignment: `init` runs before the model installs this closure,
    /// and `start()` is never called in a canvas.
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

/// Preview stand-in for the login-item service. Nonisolated to match
/// `LoginItemServicing`.
final class PreviewLoginService: LoginItemServicing {
    var isRegistered = true
    var requiresApproval = false
    func register() throws {}
    func unregister() throws {}
    func openLoginItemsSettings() {}
}
#endif
