// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Dibas Sigdel
import NepalKitCore
import SwiftUI

/// A timeline that fires at every midnight in `timeZone`, for a view that only
/// changes when the day does.
///
/// A sequence rather than a list built in `body`: `TimelineView` reads its
/// entries once and firing does not re-evaluate `body`, so a one-entry list
/// stops after the first midnight.
struct MidnightSchedule: TimelineSchedule {
    let timeZone: TimeZone

    func entries(from startDate: Date, mode: TimelineScheduleMode) -> some Sequence<Date> {
        Self.midnights(after: startDate, in: timeZone)
    }

    /// Every midnight in `timeZone` after `date`, in order. Ends only if the
    /// next midnight cannot be computed.
    static func midnights(after date: Date, in timeZone: TimeZone) -> UnfoldSequence<Date, Date?> {
        sequence(state: nextMidnight(after: date, in: timeZone)) { next in
            guard let current = next else { return nil }
            next = nextMidnight(after: current, in: timeZone)
            return current
        }
    }
}
