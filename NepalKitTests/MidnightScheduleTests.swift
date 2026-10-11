// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Dibas Sigdel
import Foundation
import Testing
import NepalKitCore
@testable import NepalKit

/// The General tab preview's timeline: every midnight, not only the next.
struct MidnightScheduleTests {
    @Test func yieldsSuccessiveNepalMidnights() throws {
        // 06:00 UTC on 11 Oct 2026; Nepal midnights fall at 18:15 UTC.
        let start = try TestDates.utc(2026, 10, 11, 6, 0)
        let three = Array(MidnightSchedule.midnights(after: start, in: nepalTimeZone).prefix(3))
        #expect(three == [
            try TestDates.utc(2026, 10, 11, 18, 15),
            try TestDates.utc(2026, 10, 12, 18, 15),
            try TestDates.utc(2026, 10, 13, 18, 15),
        ])
    }

    @Test func followsTheGivenZone() throws {
        let start = try TestDates.utc(2026, 10, 11, 6, 0)
        let utcMidnights = Array(MidnightSchedule.midnights(after: start, in: .gmt).prefix(2))
        #expect(utcMidnights == [try TestDates.utc(2026, 10, 12, 0, 0), try TestDates.utc(2026, 10, 13, 0, 0)])
    }

    @Test func theScheduleIsTheSameSequence() throws {
        let start = try TestDates.utc(2026, 10, 11, 6, 0)
        let entries = Array(MidnightSchedule(timeZone: nepalTimeZone).entries(from: start, mode: .normal).prefix(2))
        #expect(entries == Array(MidnightSchedule.midnights(after: start, in: nepalTimeZone).prefix(2)))
    }
}
