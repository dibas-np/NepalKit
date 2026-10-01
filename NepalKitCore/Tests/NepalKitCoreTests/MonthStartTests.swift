import Testing
import NepalKitCore

/// Month starts and notable month dates from published Patro reproductions
/// (independent of the table sources): KMC government grids, Hamro Patro,
/// Nepali Patro, mypatro, ashesh, rat32, khudra, nepali-calendar.com.
///
/// Months whose length was **disputed** between sources live in
/// `ArbitratedDisputeTests` instead, with the reason each was settled. This
/// suite holds the ones that were never in contention.
struct MonthStartTests {
    static let bsToADCases: [MonthStartFixture] = [
        // KMC government calendar grids, 2083.
        .init(bs: BSDay(year: 2083, month: 5, day: 1), ad: GADay(year: 2026, month: 8, day: 17), label: "Bhadra 2083"),
        .init(bs: BSDay(year: 2083, month: 6, day: 1), ad: GADay(year: 2026, month: 9, day: 17), label: "Ashoj 2083"),
        // Hamro Patro 2084 grids.
        .init(bs: BSDay(year: 2084, month: 4, day: 1), ad: GADay(year: 2027, month: 7, day: 17), label: "Shrawan 2084"),
        // nepali-calendar.com 2084 grids.
        .init(bs: BSDay(year: 2084, month: 5, day: 1), ad: GADay(year: 2027, month: 8, day: 17), label: "Bhadra 2084"),
        .init(bs: BSDay(year: 2084, month: 8, day: 1), ad: GADay(year: 2027, month: 11, day: 16), label: "Mangsir 2084"),
        // rat32 2084 grids.
        .init(bs: BSDay(year: 2084, month: 12, day: 1), ad: GADay(year: 2028, month: 3, day: 14), label: "Chaitra 2084"),
        .init(bs: BSDay(year: 2084, month: 12, day: 30), ad: GADay(year: 2028, month: 4, day: 12), label: "Chaitra end 2084"),
    ]

    static let adToBSCases: [MonthStartFixture] = [
        .init(bs: BSDay(year: 2083, month: 6, day: 1), ad: GADay(year: 2026, month: 9, day: 17), label: "Ashoj 2083"),
        .init(bs: BSDay(year: 2084, month: 12, day: 30), ad: GADay(year: 2028, month: 4, day: 12), label: "Chaitra end 2084"),
    ]

    @Test(arguments: bsToADCases)
    func publishedMonthStartBStoAD(testCase: MonthStartFixture) {
        #expect(
            bsToAD(testCase.bs, in: .v2) == testCase.ad,
            "\(testCase.label)"
        )
    }

    @Test(arguments: adToBSCases)
    func publishedMonthStartADtoBS(testCase: MonthStartFixture) {
        #expect(
            adToBS(testCase.ad, in: .v2) == testCase.bs,
            "\(testCase.label)"
        )
    }
}
