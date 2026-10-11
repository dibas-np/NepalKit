// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Dibas Sigdel
import Foundation
@testable import NepalKit

/// Test double, same shape as the `LoginItemServicing` mock. The production
/// service needs Sparkle and a live updater session, which the harness does not
/// link, so this is how the model's own logic is covered.
@MainActor
final class FakeUpdateService: UpdateServicing {
    private(set) var startCount = 0
    private(set) var checkCount = 0
    private(set) var automaticWrites = 0
    var automaticallyChecksForUpdates = true {
        didSet { automaticWrites += 1 }
    }
    var onOutcome: (@MainActor (UpdateOutcome) -> Void)?
    var onReminder: (@MainActor (Bool) -> Void)?
    var onCycleFinished: (@MainActor () -> Void)?
    var lastCheckDate: Date?

    func start() { startCount += 1 }
    func checkForUpdates() { checkCount += 1 }

    /// Simulate the framework reporting a result.
    func report(_ outcome: UpdateOutcome) { onOutcome?(outcome) }

    /// Simulate the framework finishing an update cycle.
    func finishCycle() { onCycleFinished?() }

    /// Simulate the framework raising or clearing the gentle reminder.
    func remind(_ showing: Bool) { onReminder?(showing) }
}
