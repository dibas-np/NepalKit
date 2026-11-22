// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Dibas Sigdel
import Testing
import NepalKitCore
@testable import NepalKit

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
        #expect(GridSlot.weeks(model.weeks).first?.id == AnyHashable(GregorianDate(year: 2026, month: 10, day: 18)))
    }

    @Test func identitiesDoNotChangeWhenTodayMoves() throws {
        let model = MonthGridModel(now: try TestDates.utc(2026, 10, 18, 6, 0))
        let before = GridSlot.weeks(model.weeks).flatMap(\.slots).map(\.id)
        model.refreshToday(now: try TestDates.utc(2026, 10, 19, 6, 0))
        let after = GridSlot.weeks(model.weeks).flatMap(\.slots).map(\.id)
        #expect(before == after)
    }
}
