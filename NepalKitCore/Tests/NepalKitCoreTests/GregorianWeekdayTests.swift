import Testing
@testable import NepalKitCore

/// `weekday(of: GADay)` exists so the weekday of a civil day can be had without
/// the dataset. Two reasons it has to be: the weekday belongs to the date rather
/// than to either calendar, and the today view must keep working past the
/// supported range, where no Bikram Sambat conversion is possible.
struct GregorianWeekdayTests {
    @Test func knownWeekdays() {
        // 2026-09-27 Sunday, 2026-09-28 Monday, 2028-04-13 Thursday.
        // Foundation numbers weekdays 1 = Sunday through 7 = Saturday, so Thursday is 5.
        #expect(weekday(of: GADay(year: 2026, month: 9, day: 27)) == 1)
        #expect(weekday(of: GADay(year: 2026, month: 9, day: 28)) == 2)
        #expect(weekday(of: GADay(year: 2028, month: 4, day: 13)) == 5)
    }

    @Test func agreesWithTheBikramSambatPath() {
        // Both routes must give the same answer inside the supported range;
        // if they ever diverge, one of them is wrong. Every date here is
        // deliberately inside the range: outside it there is no Bikram Sambat
        // answer to compare against, and a `continue` past a stale fixture would
        // quietly drop the case rather than fail it.
        for ad in [GADay(year: 2026, month: 9, day: 27),
                   GADay(year: 2025, month: 4, day: 14),
                   GADay(year: 2028, month: 4, day: 12),
                   GADay(year: 1918, month: 4, day: 13)]
        {
            guard let bs = adToBS(ad, in: .v2) else {
                Issue.record("Expected a Bikram Sambat answer for \(ad), which is inside the range")
                return
            }
            #expect(weekday(of: ad) == weekday(of: bs, in: .v2), "disagreement at \(ad)")
        }
    }

    @Test func worksOutsideTheSupportedRange() {
        // The whole point: these dates have no Bikram Sambat answer, but their
        // weekday is still well defined.
        #expect(adToBS(GADay(year: 2028, month: 4, day: 13), in: .v2) == nil)
        #expect(weekday(of: GADay(year: 2028, month: 4, day: 13)) == 5)
        #expect(weekday(of: GADay(year: 2030, month: 1, day: 1)) != nil)
    }

    @Test func rejectsImpossibleCivilDays() {
        // Calendar normalizes Feb 30 into March, so reject rather than answer.
        #expect(weekday(of: GADay(year: 2026, month: 2, day: 30)) == nil)
        #expect(weekday(of: GADay(year: 2026, month: 13, day: 1)) == nil)
        #expect(weekday(of: GADay(year: 2026, month: 0, day: 1)) == nil)
    }
}
