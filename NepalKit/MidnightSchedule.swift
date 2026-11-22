// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Dibas Sigdel
import NepalKitCore
import SwiftUI

struct MidnightSchedule: TimelineSchedule {
    let timeZone: TimeZone

    func entries(from startDate: Date, mode: TimelineScheduleMode) -> some Sequence<Date> {
        Self.midnights(after: startDate, in: timeZone)
    }

    static func midnights(after date: Date, in timeZone: TimeZone) -> UnfoldSequence<Date, Date?> {
        sequence(state: timeZone.nextMidnight(after: date)) { next in
            guard let current = next else { return nil }
            next = timeZone.nextMidnight(after: current)
            return current
        }
    }
}
