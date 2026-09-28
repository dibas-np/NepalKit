import Testing
@testable import NepalKitCore

/// Month starts and notable month dates from published Patro reproductions
/// (independent of the table sources): KMC government grids, Hamro Patro,
/// Nepali Patro, mypatro, ashesh, rat32, khudra, nepali-calendar.com.
///
/// Months whose length was **disputed** between sources live in
/// `ArbitratedDisputeTests` instead, with the reason each was settled. This
/// suite holds the ones that were never in contention.
struct MonthStartTests {
    static let bsToADCases: [(bs: BSDay, ad: GADay, label: String)] = [
        // KMC government calendar grids, 2083.
        (BSDay(year: 2083, month: 5, day: 1), GADay(year: 2026, month: 8, day: 17), "Bhadra 2083"),
        (BSDay(year: 2083, month: 6, day: 1), GADay(year: 2026, month: 9, day: 17), "Ashoj 2083"),
        // Hamro Patro 2084 grids.
        (BSDay(year: 2084, month: 4, day: 1), GADay(year: 2027, month: 7, day: 17), "Shrawan 2084"),
        // nepali-calendar.com 2084 grids.
        (BSDay(year: 2084, month: 5, day: 1), GADay(year: 2027, month: 8, day: 17), "Bhadra 2084"),
        (BSDay(year: 2084, month: 8, day: 1), GADay(year: 2027, month: 11, day: 16), "Mangsir 2084"),
        // rat32 2084 grids.
        (BSDay(year: 2084, month: 12, day: 1), GADay(year: 2028, month: 3, day: 14), "Chaitra 2084"),
        (BSDay(year: 2084, month: 12, day: 30), GADay(year: 2028, month: 4, day: 12), "Chaitra end 2084"),
    ]

    static let adToBSCases: [(ad: GADay, bs: BSDay, label: String)] = [
        (GADay(year: 2026, month: 9, day: 17), BSDay(year: 2083, month: 6, day: 1), "Ashoj 2083"),
        (GADay(year: 2028, month: 4, day: 12), BSDay(year: 2084, month: 12, day: 30), "Chaitra end 2084"),
    ]

    @Test(arguments: bsToADCases)
    func publishedMonthStartBStoAD(testCase: (bs: BSDay, ad: GADay, label: String)) {
        #expect(
            bsToAD(testCase.bs, in: .v2) == testCase.ad,
            "\(testCase.label)"
        )
    }

    @Test(arguments: adToBSCases)
    func publishedMonthStartADtoBS(testCase: (ad: GADay, bs: BSDay, label: String)) {
        #expect(
            adToBS(testCase.ad, in: .v2) == testCase.bs,
            "\(testCase.label)"
        )
    }
}
