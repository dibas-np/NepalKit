// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Dibas Sigdel
import Foundation
@testable import NepalKit

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

    func report(_ outcome: UpdateOutcome) { onOutcome?(outcome) }

    func finishCycle() { onCycleFinished?() }

    func remind(_ showing: Bool) { onReminder?(showing) }
}
