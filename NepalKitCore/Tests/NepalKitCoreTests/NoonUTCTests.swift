// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Dibas Sigdel
import Foundation
import Testing
import NepalKitCore

/// `noonUTC(for:)` is the GADay→Date conversion a Shortcuts result rides:
/// noon UTC, so the named civil day survives in every time zone.
struct NoonUTCTests {
    private static var utc: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .gmt
        return calendar
    }

    @Test("Noon UTC lands on the named civil day")
    func noonLandsOnTheNamedDay() throws {
        let instant = try #require(noonUTC(for: GADay(year: 2025, month: 6, day: 29)))
        let parts = Self.utc.dateComponents([.year, .month, .day, .hour], from: instant)
        #expect(parts.year == 2025 && parts.month == 6 && parts.day == 29)
        #expect(parts.hour == 12)
    }

    @Test("A civil day that does not exist yields no instant")
    func impossibleDayYieldsNoInstant() {
        // utcDate's round-trip validity check: February 30 must not
        // normalize into March 1 on the way to an instant.
        #expect(noonUTC(for: GADay(year: 2025, month: 2, day: 30)) == nil)
    }
}
