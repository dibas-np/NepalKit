import Testing
import NepalKitCore

/// The month lengths that were actually **disputed** between sources, and the
/// published material each dispute was settled against.
///
/// These are the only month boundaries in the suite that external evidence
/// independently confirmed, which makes them the most load-bearing literals here:
/// everything else about a month is self-consistent by construction. They live
/// in their own suite for that reason — so their status is visible, and so a
/// routine tidy of `MonthStartTests` cannot quietly drop them. `allDisputesAre
/// Asserted` fails if a case is removed rather than replaced.
///
/// Two arbitration phases, both recorded in SOURCES.md:
///
/// 1. **Majority vote.** The base table and a second community table disagreed
///    on 9 of 116 months; a third python table broke the ties, and the winners
///    were then confirmed against published calendars wherever those exist.
/// 2. **Post-review.** Remaining disputes settled month-by-month against
///    published Patro reproductions using tithi continuity and self-consistent
///    neighbouring-month pairs.
///
/// Note what these assertions do *not* establish. ADR-0010 records that the whole
/// table is still derived from one base table across its entire range, and that
/// the base table carries no licence file. Confirming ten months against
/// published calendars is not a licence position, and nothing here should be
/// read as one. It is also a small sample: these ten months are externally
/// validated, and the other 102 supported years have no month-level assertion at
/// all. That gap is recorded in ADR-0010 and is not closed by this file.
/// The former 2084 cases were projected, not official attestations. Their
/// replacement contracts live in Projected2084Tests and SOURCES.md.
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
        // 1989 kept the base table's row: ashesh's Kartik/Mangsir pair is
        // self-consistent (Kartik 30 = 15 Nov, Mangsir 1 = 16 Nov) and
        // tithi-continuous.
        .init(bs: BSDay(year: 1989, month: 7, day: 30), ad: GADay(year: 1932, month: 11, day: 15),
              label: "Kartik end 1989 (30 days)", source: "ashesh grid"),
        .init(bs: BSDay(year: 1989, month: 8, day: 1), ad: GADay(year: 1932, month: 11, day: 16),
              label: "Mangsir 1 1989", source: "ashesh grid"),
        // 1991 kept the second table's row: ashesh Mangsir 1991 has 30 days.
        .init(bs: BSDay(year: 1991, month: 8, day: 30), ad: GADay(year: 1934, month: 12, day: 15),
              label: "Mangsir end 1991 (30 days)", source: "ashesh grid"),
        // 1993 kept the base table's row: ashesh Ashar grid runs 31 days,
        // ending 14 July.
        .init(bs: BSDay(year: 1993, month: 3, day: 31), ad: GADay(year: 1936, month: 7, day: 14),
              label: "Ashar end 1993 (31 days)", source: "ashesh grid"),
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
