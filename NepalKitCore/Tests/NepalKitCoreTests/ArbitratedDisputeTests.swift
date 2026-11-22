import Testing
import NepalKitCore

struct ArbitratedDisputeTests {
    static let disputedMonths: Set<Int32> = [
        packed(2082, 10),
        packed(2083, 6),
        packed(1975, 5),
        packed(1975, 6),
        packed(1989, 7),
        packed(1989, 8),
        packed(1991, 8),
        packed(1993, 3),
        packed(1993, 4),
        packed(2062, 1),
        packed(2062, 2),
    ]

    private static func packed(_ year: Int, _ month: Int) -> Int32 { Int32(year * 100 + month) }

    static let bsToADCases: [ArbitratedMonthFixture] = [
        .init(bs: BikramSambatDate(year: 2082, month: 10, day: 20), ad: GregorianDate(year: 2026, month: 2, day: 3),
              label: "Magh 20 2082", source: "Nepali Patro converter"),
        .init(bs: BikramSambatDate(year: 2083, month: 6, day: 31), ad: GregorianDate(year: 2026, month: 10, day: 17),
              label: "Ashar end 2083 (31 days)", source: "KMC government calendar grid"),
        .init(bs: BikramSambatDate(year: 1975, month: 5, day: 1), ad: GregorianDate(year: 1918, month: 8, day: 17),
              label: "Bhadra 1 1975", source: "ashesh grid"),
        .init(bs: BikramSambatDate(year: 1975, month: 6, day: 1), ad: GregorianDate(year: 1918, month: 9, day: 17),
              label: "Ashwin 1 1975", source: "ashesh grid"),
        .init(bs: BikramSambatDate(year: 1989, month: 7, day: 30), ad: GregorianDate(year: 1932, month: 11, day: 15),
              label: "Kartik end 1989 (30 days)", source: "Dharan e-BPS converter"),
        .init(bs: BikramSambatDate(year: 1989, month: 8, day: 1), ad: GregorianDate(year: 1932, month: 11, day: 16),
              label: "Mangsir 1 1989", source: "Dharan e-BPS converter"),
        .init(bs: BikramSambatDate(year: 1989, month: 8, day: 29), ad: GregorianDate(year: 1932, month: 12, day: 14),
              label: "Mangsir end 1989 (29 days)", source: "Dharan e-BPS converter"),
        .init(bs: BikramSambatDate(year: 1991, month: 8, day: 30), ad: GregorianDate(year: 1934, month: 12, day: 15),
              label: "Mangsir end 1991 (30 days)", source: "ashesh grid"),
        .init(bs: BikramSambatDate(year: 1993, month: 3, day: 31), ad: GregorianDate(year: 1936, month: 7, day: 14),
              label: "Ashar end 1993 (31 days)", source: "Dharan e-BPS converter"),
        .init(bs: BikramSambatDate(year: 1993, month: 4, day: 32), ad: GregorianDate(year: 1936, month: 8, day: 15),
              label: "Shrawan end 1993 (32 days)", source: "Dharan e-BPS converter"),
        .init(bs: BikramSambatDate(year: 2062, month: 1, day: 31), ad: GregorianDate(year: 2005, month: 5, day: 14),
              label: "Baisakh end 2062 (31 days)", source: "ashesh grid"),
        .init(bs: BikramSambatDate(year: 2062, month: 2, day: 31), ad: GregorianDate(year: 2005, month: 6, day: 14),
              label: "Jestha end 2062 (31 days)", source: "ashesh grid"),
    ]

    @Test(arguments: bsToADCases)
    func arbitratedMonthLengthMatchesPublishedSource(
        testCase: ArbitratedMonthFixture
    ) {
        #expect(
            GregorianDate(testCase.bs, in: .v2) == testCase.ad,
            "\(testCase.label) — \(testCase.source)"
        )
    }

    @Test(arguments: bsToADCases)
    func arbitratedCaseIsInsideItsMonth(
        testCase: ArbitratedMonthFixture
    ) {
        let lengths = CalendarDataset.v2.monthLengths(for: testCase.bs.year)
        #expect(
            lengths?[testCase.bs.month - 1] ?? 0 >= testCase.bs.day,
            "\(testCase.label) claims day \(testCase.bs.day) of a month that is not that long"
        )
    }

    @Test func allDisputesAreAsserted() {
        let asserted = Set(Self.bsToADCases.map { Self.packed($0.bs.year, $0.bs.month) })
        #expect(
            asserted == Self.disputedMonths,
            "asserted \(asserted.sorted()) vs recorded \(Self.disputedMonths.sorted())"
        )
    }
}
