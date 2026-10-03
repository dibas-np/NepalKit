import Testing
import NepalKitCore

struct InvalidDateTests {
    static let invalidBSDays: [(day: BSDay, label: String)] = [
        (BSDay(year: 2083, month: 0, day: 11), "no month 0"),
        (BSDay(year: 2083, month: 13, day: 1), "no month 13"),
        (BSDay(year: 2083, month: 6, day: 0), "no day 0"),
        (BSDay(year: 2083, month: 7, day: 31), "Kartik 2083 has 30 days"),
        // The last day of the last year dataset 2.0.0 removed. It was a valid
        // date under 1.0.0, so this is the regression guard for the cut itself.
        (BSDay(year: 1974, month: 12, day: 30), "removed in dataset 2.0.0"),
        (BSDay(year: 1969, month: 12, day: 30), "below supported range"),
        (BSDay(year: 2085, month: 1, day: 1), "above supported range"),
    ]

    static let invalidADDays: [(day: GADay, label: String)] = [
        (GADay(year: 2024, month: 2, day: 30), "Feb 30 never exists"),
        (GADay(year: 2026, month: 13, day: 1), "no month 13"),
        // Month 0 is a different rejection than Feb 30: Feb 30 fails the
        // round-trip check in `utcDate`, month 0 fails its month guard, because
        // `Calendar` would silently normalize it into December of the year
        // before. Both must land on nil, and month 0 is the one that would
        // otherwise look like a real date.
        (GADay(year: 2026, month: 0, day: 1), "no month 0"),
        (GADay(year: 2026, month: 9, day: 0), "no day 0"),
        (GADay(year: 1918, month: 4, day: 12), "day before the range starts"),
        (GADay(year: 1913, month: 4, day: 12), "below supported range"),
        (GADay(year: 2028, month: 4, day: 13), "above supported range"),
    ]

    @Test(arguments: invalidBSDays)
    func invalidBSDatesReturnNil(testCase: (day: BSDay, label: String)) {
        #expect(bsToAD(testCase.day, in: .v2) == nil, "\(testCase.label)")
    }

    @Test(arguments: invalidADDays)
    func invalidADDatesReturnNil(testCase: (day: GADay, label: String)) {
        #expect(adToBS(testCase.day, in: .v2) == nil, "\(testCase.label)")
    }

    @Test(arguments: [0, -1])
    func corruptIntermediateRowRejectsReverseConversion(monthLength: Int) throws {
        let validMonths = [Int](repeating: 30, count: 12)
        var corruptMonths = validMonths
        corruptMonths[5] = monthLength
        let anchor = GADay(year: 2000, month: 1, day: 1)
        let broken = CalendarDataset(
            version: "corrupt-intermediate-test",
            years: [2000: validMonths, 2001: corruptMonths, 2002: validMonths],
            anchorBS: BSDay(year: 2000, month: 1, day: 1),
            anchorAD: anchor,
            supportedRange: 2000 ... 2002
        )

        #expect(adToBS(anchor, in: broken) == BSDay(year: 2000, month: 1, day: 1))
        for offset in [400, 800] {
            let day = try #require(anchor.advanced(byDays: offset))
            #expect(adToBS(day, in: broken) == nil)
        }
    }
}
