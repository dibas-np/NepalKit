import Testing
import NepalKitCore

struct CalendarDatasetTests {
    @Test func bundledDatasetDeclaresVersionAndRange() {
        let dataset = CalendarDataset.v2

        // 2.0.0 dropped 1970–1974, which had no corroborating second source.
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
