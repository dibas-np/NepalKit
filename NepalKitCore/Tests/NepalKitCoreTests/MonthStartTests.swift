import Testing
import NepalKitCore

/// Month starts and notable month dates from published Patro reproductions
/// (independent of the table sources): KMC government grids, Hamro Patro,
/// Nepali Patro, mypatro, ashesh, rat32, khudra, nepali-calendar.com.
///
/// Months whose length was **disputed** between sources live in
/// `ArbitratedDisputeTests` instead, with the reason each was settled. This
/// suite holds the ones that were never in contention. Provisional 2084
/// contracts live in Projected2084Tests, not among published-calendar fixtures.
struct MonthStartTests {
    static let bsToADCases: [MonthStartFixture] = [
        // KMC government calendar grids, 2083.
        .init(bs: BSDay(year: 2083, month: 5, day: 1), ad: GADay(year: 2026, month: 8, day: 17), label: "Bhadra 2083"),
        .init(bs: BSDay(year: 2083, month: 6, day: 1), ad: GADay(year: 2026, month: 9, day: 17), label: "Ashoj 2083"),
    ]

    static let adToBSCases: [MonthStartFixture] = [
        .init(bs: BSDay(year: 2083, month: 6, day: 1), ad: GADay(year: 2026, month: 9, day: 17), label: "Ashoj 2083"),
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
