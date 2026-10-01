// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Dibas Sigdel
import Foundation
import Testing
import NepalKitCore

/// `noonUTC(for:)` is the GADay→Date conversion a Shortcuts result rides:
/// noon UTC, so the named civil day survives from UTC−12 inclusive through
/// UTC+12 exclusive and rolls to the following local day at UTC+12 and beyond
/// (pinned below).
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

    @Test("The named day survives below UTC+12 and rolls over at UTC+12", arguments: [
        ("UTC-12:00", -43_200, 0),
        ("UTC+05:45", 20_700, 0),
        ("UTC+11:00", 39_600, 0),
        ("UTC+11:30", 41_400, 0),
        ("UTC+12:00", 43_200, 1),
        ("UTC+13:00", 46_800, 1),
        ("UTC+14:00", 50_400, 1),
    ])
    func daySurvivalByOffset(label: String, offsetSeconds: Int, dayShift: Int) throws {
        let instant = try #require(noonUTC(for: GADay(year: 2025, month: 6, day: 29)))
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(secondsFromGMT: offsetSeconds))
        let parts = calendar.dateComponents([.year, .month, .day], from: instant)
        #expect(
            parts.year == 2025 && parts.month == 6 && parts.day == 29 + dayShift,
            "\(label)"
        )
    }
}
