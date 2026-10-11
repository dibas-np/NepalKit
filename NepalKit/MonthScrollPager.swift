// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Dibas Sigdel
import AppKit

/// Turns scroll-wheel and trackpad scrolling over the grid into whole-month
/// steps, at most one per gesture.
///
/// A trackpad reports a swipe as dozens of small precise deltas followed by
/// momentum. Paging on each delta would fly through a year per flick, so a
/// gesture turns the page once, after `threshold` points of travel, and its
/// momentum is ignored. A mouse wheel has no gesture to speak of: each notch is
/// one discrete event and turns one page, which is how a wheel pages anywhere.
struct MonthScrollPager {
    /// Where an event sits in its gesture, read from `NSEvent` by the view.
    enum Phase {
        case began, changed, ended, momentum
        /// A wheel notch: no gesture around it.
        case discrete

        /// An event's place in its gesture, from `NSEvent`'s two phase fields.
        /// Momentum is checked first because a momentum event carries no
        /// gesture phase of its own; an event with neither is a wheel notch.
        /// A gesture that is cancelled, waiting to begin or resting reads as
        /// ended, which turns no page.
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

    /// Points of trackpad travel before a gesture turns the page. Enough that
    /// a resting finger's drift or a mostly sideways swipe does not page, small
    /// enough that a deliberate short swipe does.
    static let threshold = 24.0

    private var travel = 0.0
    private var hasPaged = false

    /// The month step this event makes: 1 for the next month, -1 for the
    /// previous, 0 for none. Scrolling down (a negative delta, as AppKit
    /// reports it after the user's scroll-direction setting) moves forward in
    /// time, as scrolling down a document does.
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
