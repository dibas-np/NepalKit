// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Dibas Sigdel
import Testing
import NepalKitCore

/// Regression contracts for the user-approved provisional 2084 projection.
/// These fixtures encode that decision, not independently attested calendar data.
/// Reconcile all twelve months against the official Patro when available.
struct Projected2084Tests {
    static let monthStarts: [MonthStartFixture] = [
        .init(bs: BSDay(year: 2084, month: 1, day: 1), ad: GADay(year: 2027, month: 4, day: 14), label: "Baisakh"),
        .init(bs: BSDay(year: 2084, month: 2, day: 1), ad: GADay(year: 2027, month: 5, day: 15), label: "Jestha"),
        .init(bs: BSDay(year: 2084, month: 3, day: 1), ad: GADay(year: 2027, month: 6, day: 16), label: "Ashar"),
        .init(bs: BSDay(year: 2084, month: 4, day: 1), ad: GADay(year: 2027, month: 7, day: 17), label: "Shrawan"),
        .init(bs: BSDay(year: 2084, month: 5, day: 1), ad: GADay(year: 2027, month: 8, day: 18), label: "Bhadra"),
        .init(bs: BSDay(year: 2084, month: 6, day: 1), ad: GADay(year: 2027, month: 9, day: 18), label: "Ashoj"),
        .init(bs: BSDay(year: 2084, month: 7, day: 1), ad: GADay(year: 2027, month: 10, day: 18), label: "Kartik"),
        .init(bs: BSDay(year: 2084, month: 8, day: 1), ad: GADay(year: 2027, month: 11, day: 17), label: "Mangsir"),
        .init(bs: BSDay(year: 2084, month: 9, day: 1), ad: GADay(year: 2027, month: 12, day: 17), label: "Poush"),
        .init(bs: BSDay(year: 2084, month: 10, day: 1), ad: GADay(year: 2028, month: 1, day: 15), label: "Magh"),
        .init(bs: BSDay(year: 2084, month: 11, day: 1), ad: GADay(year: 2028, month: 2, day: 13), label: "Falgun"),
        .init(bs: BSDay(year: 2084, month: 12, day: 1), ad: GADay(year: 2028, month: 3, day: 14), label: "Chaitra"),
    ]

    @Test(arguments: monthStarts)
    func provisionalMonthStartBothDirections(testCase: MonthStartFixture) {
        #expect(bsToAD(testCase.bs, in: .v2) == testCase.ad)
        #expect(adToBS(testCase.ad, in: .v2) == testCase.bs)
    }

    @Test func birthdayMappingBothDirections() {
        let birthday = BSDay(year: 2084, month: 5, day: 22)
        let gregorian = GADay(year: 2027, month: 9, day: 8)
        #expect(bsToAD(birthday, in: .v2) == gregorian)
        #expect(adToBS(gregorian, in: .v2) == birthday)
    }

    @Test func revisedMonthEndsAndInvalidDays() {
        #expect(bsToAD(BSDay(year: 2084, month: 2, day: 32), in: .v2) == GADay(year: 2027, month: 6, day: 15))
        #expect(bsToAD(BSDay(year: 2084, month: 3, day: 32), in: .v2) == nil)
        #expect(bsToAD(BSDay(year: 2084, month: 4, day: 32), in: .v2) == GADay(year: 2027, month: 8, day: 17))
        #expect(bsToAD(BSDay(year: 2084, month: 10, day: 30), in: .v2) == nil)
        #expect(bsToAD(BSDay(year: 2084, month: 12, day: 31), in: .v2) == nil)
    }

    @Test func unchangedSupportedBoundsAndRevisedVersion() {
        #expect(CalendarDataset.v2.version == "2.0.1")
        #expect(CalendarDataset.v2.gregorianStart == GADay(year: 1918, month: 4, day: 13))
        #expect(CalendarDataset.v2.gregorianEnd == GADay(year: 2028, month: 4, day: 12))
        #expect(adToBS(GADay(year: 2028, month: 4, day: 13), in: .v2) == nil)
    }
}
