import XCTest
@testable import NepalKitCore

final class CalendarDatasetTests: XCTestCase {
    func testSampleDatasetDeclaresVersionAndRange() {
        let dataset = CalendarDataset.sample

        XCTAssertEqual(dataset.version, "0.1.0-skeleton")
        XCTAssertEqual(dataset.supportedRange, 2082 ... 2083)
    }

    func testEveryYearHasTwelveValidMonths() {
        let dataset = CalendarDataset.sample

        for year in dataset.supportedRange {
            let months = dataset.monthLengths(for: year)
            XCTAssertEqual(months?.count, 12, "BS year \(year) must have 12 months")
            for length in months ?? [] {
                XCTAssertTrue((29 ... 32).contains(length), "Month length \(length) out of range in \(year)")
            }
        }
    }

    func testSupportedRangeHasNoGaps() {
        let dataset = CalendarDataset.sample

        for year in dataset.supportedRange {
            XCTAssertNotNil(dataset.monthLengths(for: year), "Missing data for BS year \(year)")
        }
        XCTAssertNil(dataset.monthLengths(for: dataset.supportedRange.lowerBound - 1))
        XCTAssertNil(dataset.monthLengths(for: dataset.supportedRange.upperBound + 1))
    }
}
