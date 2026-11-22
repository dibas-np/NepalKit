// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Dibas Sigdel
import AppKit

/// Turns scrolling over the grid into whole-month steps. A trackpad gesture
/// pages once after `threshold` points and ignores momentum; each wheel notch pages once.
struct MonthScrollPager {
    enum Phase {
        case began, changed, ended, momentum
        case discrete

        /// A momentum event has no gesture phase, so momentum is checked first.
        init(phase: NSEvent.Phase, momentumPhase: NSEvent.Phase) {
            if !momentumPhase.isEmpty {
                self = .momentum
            } else if phase.isEmpty {
                self = .discrete
            } else if phase.contains(.began) {
                self = .began
            } else if phase.contains(.changed) {
                self = .changed
            } else {
                self = .ended
            }
        }
    }

    static let threshold = 24.0

    private var travel = 0.0
    private var hasPaged = false

    /// Scrolling down (negative delta) moves forward, as in a document.
    mutating func step(deltaY: Double, phase: Phase) -> Int {
        switch phase {
        case .began:
            travel = 0
            hasPaged = false
            return accumulate(deltaY)
        case .changed:
            return accumulate(deltaY)
        case .ended:
            travel = 0
            return 0
        case .momentum:
            return 0
        case .discrete:
            return Self.direction(deltaY)
        }
    }

    private mutating func accumulate(_ deltaY: Double) -> Int {
        guard !hasPaged else { return 0 }
        travel += deltaY
        guard abs(travel) >= Self.threshold else { return 0 }
        hasPaged = true
        return Self.direction(travel)
    }

    private static func direction(_ deltaY: Double) -> Int {
        deltaY < 0 ? 1 : deltaY > 0 ? -1 : 0
    }
}
