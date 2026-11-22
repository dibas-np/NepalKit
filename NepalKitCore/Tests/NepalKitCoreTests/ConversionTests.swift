import Testing
import NepalKitCore

struct ConversionTests {
    @Test func bsToADKnownDate() {
        #expect(GregorianDate(BikramSambatDate(year: 2083, month: 6, day: 11), in: .v2) == GregorianDate(year: 2026, month: 9, day: 27))
    }

    @Test func adToBSKnownDate() {
        #expect(BikramSambatDate(GregorianDate(year: 2026, month: 9, day: 27), in: .v2) == BikramSambatDate(year: 2083, month: 6, day: 11))
    }

    @Test func weekdayOfKnownDateIsSunday() {
        #expect(BikramSambatDate(year: 2083, month: 6, day: 11).weekday(in: .v2) == 1)
    }
}
