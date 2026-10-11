// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Dibas Sigdel
import Foundation
import Testing
import NepalKitCore
@testable import NepalKit

/// The popover's per-second tick and what it touches: today and the secondary
/// row's visibility are stored and change only when they really do, and the
/// menu bar's poll writes only when the day has turned.
@MainActor
struct PopoverClockTests {
    /// One tick of `refreshWhileVisible` at `instant`, then stop.
    private func tick(_ clock: ClockModel) async {
        await clock.refreshWhileVisible()
    }

    private func clock(now: Date, tickTo instant: Date, local: String = "America/New_York") throws -> ClockModel {
        let zone = try #require(TimeZone(identifier: local))
        return ClockModel(
            now: now, localTimeZone: zone,
            currentTime: { instant },
            sleep: { _ in throw CancellationError() }
        )
    }

    @Test func todayMovesAtNepalMidnightAndNotBefore() async throws {
        // Nepal midnight is 18:15 UTC.
        let clock = try clock(now: try TestDates.utc(2026, 9, 26, 18, 13), tickTo: try TestDates.utc(2026, 9, 26, 18, 14))
        let before = clock.today
        await tick(clock)
        #expect(clock.today == before)

        let later = try self.clock(now: try TestDates.utc(2026, 9, 26, 18, 14), tickTo: try TestDates.utc(2026, 9, 26, 18, 16))
        await tick(later)
        #expect(later.today == GADay(year: 2026, month: 9, day: 27))
        #expect(later.todayBSDate() == BSDay(year: 2083, month: 6, day: 11))
    }

    @Test func theSecondaryRowIsStoredAndFollowsTheReference() throws {
        let newYork = try clock(now: try TestDates.utc(2026, 9, 27, 12, 0), tickTo: try TestDates.utc(2026, 9, 27, 12, 0))
        #expect(newYork.showsSecondaryClock)
        let kathmandu = try clock(now: try TestDates.utc(2026, 9, 27, 12, 0), tickTo: try TestDates.utc(2026, 9, 27, 12, 0), local: "Asia/Kathmandu")
        #expect(!kathmandu.showsSecondaryClock)
    }

    @Test func switchingToLocalTimeMovesTodayAtOnce() throws {
        // 23:30 UTC on 26 Sep: 27 Sep in Nepal, still 26 Sep in New York.
        let clock = try clock(now: try TestDates.utc(2026, 9, 26, 23, 30), tickTo: try TestDates.utc(2026, 9, 26, 23, 30))
        #expect(clock.today == GADay(year: 2026, month: 9, day: 27))
        clock.setTimeReference(.local)
        #expect(clock.today == GADay(year: 2026, month: 9, day: 26))
    }

    @Test func theMenuBarPollWritesOnlyWhenTheDayHasTurned() throws {
        let current = MenuBarModel(now: .now, refreshes: false, schedulesMidnightFire: false)
        let before = current.now
        current.pollForMissedChange()
        #expect(current.now == before)

        let stale = MenuBarModel(now: try TestDates.utc(2026, 1, 1, 6, 0), refreshes: false, schedulesMidnightFire: false)
        stale.pollForMissedChange()
        #expect(stale.now > (try TestDates.utc(2026, 1, 2, 0, 0)))
    }
}
