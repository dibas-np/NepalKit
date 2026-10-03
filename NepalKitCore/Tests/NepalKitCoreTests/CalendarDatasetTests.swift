import Testing
import NepalKitCore

struct CalendarDatasetTests {
    @Test func bundledDatasetDeclaresVersionAndRange() {
        let dataset = CalendarDataset.v2

        // Dataset 2.0.0 cut 1970-1974: those five years rested on the base
        // source alone, with no second table to corroborate them.
        #expect(dataset.version == "2.0.1")
        #expect(dataset.supportedRange == 1975 ... 2084)
    }

    @Test(arguments: CalendarDataset.v2.supportedRange)
    func everyYearHasTwelveValidMonths(year: Int) {
        let months = CalendarDataset.v2.monthLengths(for: year)

        #expect(months?.count == 12, "\(year) must have 12 months")
        for length in months ?? [] {
            #expect((29 ... 32).contains(length), "month length \(length) out of range in \(year)")
        }
        #expect([365, 366].contains(months?.reduce(0, +) ?? 0), "\(year) must span 365/366 days")
    }

    @Test func declaredRangeMatchesTableKeys() {
        // The engine indexes exactly the declared range, so a table that
        // disagrees with the range would silently produce zero-length years.
        // The dataset's own init now traps on a range year with no row, and
        // the index cache this used to check directly is a consequence of that
        // plus the row sums — whose public consequence (each New Year landing
        // on its pinned Gregorian date) NewYearBoundaryTests asserts exactly.
        let dataset = CalendarDataset.v2

        #expect(Set(dataset.years.keys) == Set(dataset.supportedRange))
    }

    @Test func supportedRangeHasNoGaps() {
        let dataset = CalendarDataset.v2

        for year in dataset.supportedRange {
            #expect(dataset.monthLengths(for: year) != nil, "missing data for \(year)")
        }
        #expect(dataset.monthLengths(for: dataset.supportedRange.lowerBound - 1) == nil)
        #expect(dataset.monthLengths(for: dataset.supportedRange.upperBound + 1) == nil)
    }
}
