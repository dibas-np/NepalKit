// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Dibas Sigdel
import NepalKitCore
import SwiftUI

/// A timeline that fires at every midnight in `timeZone`, for a view that only
/// changes when the day does.
///
/// A sequence, not a list built in `body`: `TimelineView` reads entries once, so a
/// one-entry list stops after the first midnight.
struct MidnightSchedule: TimelineSchedule {
    let timeZone: TimeZone

    func entries(from startDate: Date, mode: TimelineScheduleMode) -> some Sequence<Date> {
        Self.midnights(after: startDate, in: timeZone)
    }

    /// Every midnight in `timeZone` after `date`.
    static func midnights(after date: Date, in timeZone: TimeZone) -> UnfoldSequence<Date, Date?> {
        sequence(state: timeZone.nextMidnight(after: date)) { next in
            guard let current = next else { return nil }
            next = timeZone.nextMidnight(after: current)
            return current
        }
    }
}
