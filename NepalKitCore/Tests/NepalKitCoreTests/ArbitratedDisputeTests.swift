import Testing
import NepalKitCore

/// Regression fixtures for retained calendar decisions.
///
/// SOURCES.md records the current askbuddie base and local exceptions. The
/// 1989 and 1993 pairs were checked against the Dharan e-BPS converter on
/// 3 October 2026. Other fixtures retain their original evidence attribution;
/// they do not establish complete independent verification of the dataset.
/// The local 2084 projection is tested separately in Projected2084Tests.
struct ArbitratedDisputeTests {
    /// Every arbitrated month decision, as a (year, month) pair. Presence is
    /// asserted below so the set cannot shrink silently.
    static let disputedMonths: Set<Int32> = [
        // Phase 1 — majority vote, confirmed against published calendars.
        packed(2082, 10), // Magh
        packed(2083, 6),  // Ashoj
        // Phase 2 — post-review arbitration against published Patro.
        packed(1975, 5),  // Bhadra
        packed(1975, 6),  // Ashwin
        packed(1989, 7),  // Kartik
        packed(1989, 8),  // Mangsir
        packed(1991, 8),  // Mangsir
        packed(1993, 3),  // Ashar
        packed(1993, 4),  // Shrawan
        packed(2062, 1),  // Baisakh
        packed(2062, 2),  // Jestha
    ]

    /// Year and month packed into one comparable integer, so the set above is a
    /// literal rather than a list of opaque decimal numbers.
    private static func packed(_ year: Int, _ month: Int) -> Int32 { Int32(year * 100 + month) }

    static let bsToADCases: [ArbitratedMonthFixture] = [
        // -- Phase 1: majority vote, confirmed against published calendars --
        // 2082 Magh 20 <-> 3 Feb 2026, Nepali Patro converter.
        .init(bs: BSDay(year: 2082, month: 10, day: 20), ad: GADay(year: 2026, month: 2, day: 3),
              label: "Magh 20 2082", source: "Nepali Patro converter"),
        // 2083: KMC government grid settled that Ashoj has 31 days, not 30.
        .init(bs: BSDay(year: 2083, month: 6, day: 31), ad: GADay(year: 2026, month: 10, day: 17),
              label: "Ashar end 2083 (31 days)", source: "KMC government calendar grid"),
        // -- Phase 2: post-review arbitration against published Patro --
        // 1975 kept the second table's row: the ashesh Bhadra/Ashwin pair is
        // Navami-to-Dwadashi tithi-continuous, and the Bhadra grid is missing
        // its two trailing days.
        .init(bs: BSDay(year: 1975, month: 5, day: 1), ad: GADay(year: 1918, month: 8, day: 17),
              label: "Bhadra 1 1975", source: "ashesh grid"),
        .init(bs: BSDay(year: 1975, month: 6, day: 1), ad: GADay(year: 1918, month: 9, day: 17),
              label: "Ashwin 1 1975", source: "ashesh grid"),
        // Dharan e-BPS confirms Kartik/Mangsir 1989 as 30/29 days.
        .init(bs: BSDay(year: 1989, month: 7, day: 30), ad: GADay(year: 1932, month: 11, day: 15),
              label: "Kartik end 1989 (30 days)", source: "Dharan e-BPS converter"),
        .init(bs: BSDay(year: 1989, month: 8, day: 1), ad: GADay(year: 1932, month: 11, day: 16),
              label: "Mangsir 1 1989", source: "Dharan e-BPS converter"),
        .init(bs: BSDay(year: 1989, month: 8, day: 29), ad: GADay(year: 1932, month: 12, day: 14),
              label: "Mangsir end 1989 (29 days)", source: "Dharan e-BPS converter"),
        // 1991 kept the second table's row: ashesh Mangsir 1991 has 30 days.
        .init(bs: BSDay(year: 1991, month: 8, day: 30), ad: GADay(year: 1934, month: 12, day: 15),
              label: "Mangsir end 1991 (30 days)", source: "ashesh grid"),
        // Dharan e-BPS confirms Ashar/Shrawan 1993 as 31/32 days.
        .init(bs: BSDay(year: 1993, month: 3, day: 31), ad: GADay(year: 1936, month: 7, day: 14),
              label: "Ashar end 1993 (31 days)", source: "Dharan e-BPS converter"),
        .init(bs: BSDay(year: 1993, month: 4, day: 32), ad: GADay(year: 1936, month: 8, day: 15),
              label: "Shrawan end 1993 (32 days)", source: "Dharan e-BPS converter"),
        // 2062 kept the second table's rows: ashesh Baisakh/Jestha 31/31,
        // tithi-continuous.
        .init(bs: BSDay(year: 2062, month: 1, day: 31), ad: GADay(year: 2005, month: 5, day: 14),
              label: "Baisakh end 2062 (31 days)", source: "ashesh grid"),
        .init(bs: BSDay(year: 2062, month: 2, day: 31), ad: GADay(year: 2005, month: 6, day: 14),
              label: "Jestha end 2062 (31 days)", source: "ashesh grid"),
    ]

    @Test(arguments: bsToADCases)
    func arbitratedMonthLengthMatchesPublishedSource(
        testCase: ArbitratedMonthFixture
    ) {
        #expect(
            bsToAD(testCase.bs, in: .v2) == testCase.ad,
            "\(testCase.label) — \(testCase.source)"
        )
    }

    /// Each asserted day is a real day of its month, not a day that happens to
    /// convert. Without this, a case asserting day 31 of a 30-day month would
    /// pass vacuously as `nil` only if compared wrongly — this makes the month
    /// length itself explicit and catches a row change that would silently
    /// shorten the month the dispute was about.
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

    /// The set of arbitrated months cannot shrink without this failing. These
    /// are the suite's only externally confirmed month lengths; losing one to a
    /// refactor would be invisible otherwise.
    @Test func allDisputesAreAsserted() {
        let asserted = Set(Self.bsToADCases.map { Self.packed($0.bs.year, $0.bs.month) })
        #expect(
            asserted == Self.disputedMonths,
            "asserted \(asserted.sorted()) vs recorded \(Self.disputedMonths.sorted())"
        )
    }
}
