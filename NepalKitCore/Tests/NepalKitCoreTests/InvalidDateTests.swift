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
}
