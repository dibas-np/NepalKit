import Testing
@testable import NepalKitCore

/// Month starts and notable month dates from published Patro reproductions
/// (independent of the table sources): KMC government grids, Hamro Patro,
/// Nepali Patro, mypatro, ashesh, rat32, khudra, nepali-calendar.com.
struct MonthStartTests {
    static let bsToADCases: [(bs: BSDay, ad: GADay, label: String)] = [
        // KMC government calendar grids, 2083.
        (BSDay(year: 2083, month: 5, day: 1), GADay(year: 2026, month: 8, day: 17), "Bhadra 2083"),
        (BSDay(year: 2083, month: 6, day: 1), GADay(year: 2026, month: 9, day: 17), "Ashoj 2083"),
        (BSDay(year: 2083, month: 6, day: 31), GADay(year: 2026, month: 10, day: 17), "Phulpati 2083"),
        // Nepali Patro converter.
        (BSDay(year: 2082, month: 10, day: 20), GADay(year: 2026, month: 2, day: 3), "Magh 2082"),
        // Hamro Patro 2084 grids.
        (BSDay(year: 2084, month: 2, day: 1), GADay(year: 2027, month: 5, day: 15), "Jestha 2084"),
        (BSDay(year: 2084, month: 3, day: 1), GADay(year: 2027, month: 6, day: 15), "Ashar 2084"),
        (BSDay(year: 2084, month: 4, day: 1), GADay(year: 2027, month: 7, day: 17), "Shrawan 2084"),
        // nepali-calendar.com 2084 grids.
        (BSDay(year: 2084, month: 5, day: 1), GADay(year: 2027, month: 8, day: 17), "Bhadra 2084"),
        (BSDay(year: 2084, month: 8, day: 1), GADay(year: 2027, month: 11, day: 16), "Mangsir 2084"),
        // rat32 2084 grids.
        (BSDay(year: 2084, month: 12, day: 1), GADay(year: 2028, month: 3, day: 14), "Chaitra 2084"),
        (BSDay(year: 2084, month: 12, day: 30), GADay(year: 2028, month: 4, day: 12), "Chaitra end 2084"),
        // ashesh 1970-2100 grids (dispute arbitration).
        (BSDay(year: 1975, month: 5, day: 1), GADay(year: 1918, month: 8, day: 17), "Bhadra 1975"),
        (BSDay(year: 1975, month: 6, day: 1), GADay(year: 1918, month: 9, day: 17), "Ashwin 1975"),
        (BSDay(year: 1989, month: 7, day: 30), GADay(year: 1932, month: 11, day: 15), "Kartik end 1989"),
        (BSDay(year: 1989, month: 8, day: 1), GADay(year: 1932, month: 11, day: 16), "Mangsir 1989"),
        (BSDay(year: 1991, month: 8, day: 30), GADay(year: 1934, month: 12, day: 15), "Mangsir end 1991"),
        (BSDay(year: 1993, month: 3, day: 31), GADay(year: 1936, month: 7, day: 14), "Ashar end 1993"),
        (BSDay(year: 2062, month: 1, day: 31), GADay(year: 2005, month: 5, day: 14), "Baisakh end 2062"),
        (BSDay(year: 2062, month: 2, day: 31), GADay(year: 2005, month: 6, day: 14), "Jestha end 2062"),
    ]

    static let adToBSCases: [(ad: GADay, bs: BSDay, label: String)] = [
        (GADay(year: 2026, month: 9, day: 17), BSDay(year: 2083, month: 6, day: 1), "Ashoj 2083"),
        (GADay(year: 1932, month: 11, day: 16), BSDay(year: 1989, month: 8, day: 1), "Mangsir 1989"),
        (GADay(year: 2005, month: 6, day: 14), BSDay(year: 2062, month: 2, day: 31), "Jestha end 2062"),
        (GADay(year: 2028, month: 4, day: 12), BSDay(year: 2084, month: 12, day: 30), "Chaitra end 2084"),
    ]

    @Test(arguments: bsToADCases)
    func publishedMonthStartBStoAD(testCase: (bs: BSDay, ad: GADay, label: String)) {
        #expect(
            bsToAD(testCase.bs, in: .v1) == testCase.ad,
            "\(testCase.label)"
        )
    }

    @Test(arguments: adToBSCases)
    func publishedMonthStartADtoBS(testCase: (ad: GADay, bs: BSDay, label: String)) {
        #expect(
            adToBS(testCase.ad, in: .v1) == testCase.bs,
            "\(testCase.label)"
        )
    }
}
