import Foundation
import Testing

/// Shared UTC instant builder for core tests. One helper instead of a copy
/// per suite.
enum UTCDateFixture {
    static func utc(_ year: Int, _ month: Int, _ day: Int, _ hour: Int, _ minute: Int, _ second: Int = 0) throws -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .gmt
        return try #require(calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute, second: second)))
    }
}
