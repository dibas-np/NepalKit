// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Dibas Sigdel
import Testing
import NepalKitCore
@testable import NepalKit

/// The month grid's view identity: days by date, weeks by their first day,
/// never by position, so an identity outlives the month it was drawn in.
@MainActor
struct GridSlotTests {
    @Test func everyIdentityIsUniqueWithinAMonth() throws {
        let model = MonthGridModel(now: try TestDates.utc(2026, 10, 18, 6, 0))
        let weeks = GridSlot.weeks(model.weeks)
        #expect(Set(weeks.map(\.id)).count == weeks.count)
        let slots = weeks.flatMap(\.slots)
        #expect(Set(slots.map(\.id)).count == slots.count)
    }

    @Test func aDayIsIdentifiedByItsGregorianDate() throws {
        let model = MonthGridModel(now: try TestDates.utc(2026, 10, 18, 6, 0))
        let slots = GridSlot.weeks(model.weeks).flatMap(\.slots)
        for slot in slots {
            let day = try #require(slot.day)
            #expect(slot.id == AnyHashable(day.gregorian))
        }
        // Kartik 2083 starts on Sunday 18 October 2026, the first week's id.
        #expect(GridSlot.weeks(model.weeks).first?.id == AnyHashable(GADay(year: 2026, month: 10, day: 18)))
    }

    @Test func identitiesDoNotChangeWhenTodayMoves() throws {
        let model = MonthGridModel(now: try TestDates.utc(2026, 10, 18, 6, 0))
        let before = GridSlot.weeks(model.weeks).flatMap(\.slots).map(\.id)
        model.refreshToday(now: try TestDates.utc(2026, 10, 19, 6, 0))
        let after = GridSlot.weeks(model.weeks).flatMap(\.slots).map(\.id)
        #expect(before == after)
    }
}
