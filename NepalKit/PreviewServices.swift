// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Dibas Sigdel
#if DEBUG
import Foundation

@MainActor
final class PreviewUpdateService: UpdateServicing {
    var automaticallyChecksForUpdates = true
    var lastCheckDate: Date?
    var onReminder: (@MainActor (Bool) -> Void)?
    var onCycleFinished: (@MainActor () -> Void)?

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

final class PreviewLoginService: LoginItemServicing {
    var isRegistered = true
    var requiresApproval = false
    func register() throws {}
    func unregister() throws {}
    func openLoginItemsSettings() {}
}
#endif
