import Testing
import NepalKitCore

struct GregorianWeekdayTests {
    @Test func knownWeekdays() {
        #expect(GregorianDate(year: 2026, month: 9, day: 27).weekday == 1)
        #expect(GregorianDate(year: 2026, month: 9, day: 28).weekday == 2)
        #expect(GregorianDate(year: 2028, month: 4, day: 13).weekday == 5)
    }

    @Test func agreesWithTheBikramSambatPath() {
        for ad in [GregorianDate(year: 2026, month: 9, day: 27),
                   GregorianDate(year: 2025, month: 4, day: 14),
                   GregorianDate(year: 2028, month: 4, day: 12),
                   GregorianDate(year: 1918, month: 4, day: 13)] {
            guard let bs = BikramSambatDate(ad, in: .v2) else {
                Issue.record("Expected a Bikram Sambat answer for \(ad), which is inside the range")
                return
            }
            #expect(ad.weekday == bs.weekday(in: .v2), "disagreement at \(ad)")
        }
    }

    @Test func worksOutsideTheSupportedRange() {
        #expect(BikramSambatDate(GregorianDate(year: 2028, month: 4, day: 13), in: .v2) == nil)
        #expect(GregorianDate(year: 2028, month: 4, day: 13).weekday == 5)
        #expect(GregorianDate(year: 2030, month: 1, day: 1).weekday != nil)
    }

    @Test func rejectsImpossibleCivilDays() {
        #expect(GregorianDate(year: 2026, month: 2, day: 30).weekday == nil)
        #expect(GregorianDate(year: 2026, month: 13, day: 1).weekday == nil)
        #expect(GregorianDate(year: 2026, month: 0, day: 1).weekday == nil)
    }
}
