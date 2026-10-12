// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Dibas Sigdel
import AppKit

/// Turns scrolling over the grid into whole-month steps.
///
/// A trackpad swipe is dozens of small deltas then momentum; paging on each
/// would fly through a year per flick. So a gesture pages once, after
/// `threshold` points, and momentum is ignored. Each wheel notch pages once.
struct MonthScrollPager {
    enum Phase {
        case began, changed, ended, momentum
        /// A wheel notch: no gesture around it.
        case discrete

        /// Momentum first, as a momentum event has no gesture phase; neither
        /// is a wheel notch. Cancelled, may-begin or stationary reads as ended.
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

    /// Enough to ignore a resting finger's drift or a sideways swipe, small
    /// enough for a short deliberate one.
    static let threshold = 24.0

    private var travel = 0.0
    private var hasPaged = false

    /// The month step: 1, -1 or 0. Scrolling down (negative delta, after the
    /// user's scroll-direction setting) moves forward, as in a document.
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
