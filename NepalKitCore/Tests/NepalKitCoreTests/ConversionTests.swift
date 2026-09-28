import Testing
@testable import NepalKitCore

struct ConversionTests {
    @Test func bsToADKnownDate() {
        #expect(bsToAD(BSDay(year: 2083, month: 6, day: 11), in: .v2) == GADay(year: 2026, month: 9, day: 27))
    }

    @Test func adToBSKnownDate() {
        #expect(adToBS(GADay(year: 2026, month: 9, day: 27), in: .v2) == BSDay(year: 2083, month: 6, day: 11))
    }

    @Test func weekdayOfKnownDateIsSunday() {
        // 27 September 2026 is a Sunday; weekday 1 is Sunday.
        #expect(weekday(of: BSDay(year: 2083, month: 6, day: 11), in: .v2) == 1)
    }
}
