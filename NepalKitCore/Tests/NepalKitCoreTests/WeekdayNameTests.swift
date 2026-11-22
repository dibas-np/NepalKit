import Testing
import NepalKitCore

struct WeekdayNameTests {
    @Test func nepaliWeekdayNames() {
        let expected = ["आइत", "सोम", "मंगल", "बुध", "बिही", "शुक्र", "शनि"]
        for day in 1 ... 7 {
            #expect(BikramSambatDate.weekdayName(day, style: .nepali) == expected[day - 1], "day \(day)")
        }
    }

    @Test func transliteratedWeekdayNamesAreEnglish() {
        let expected = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
        for day in 1 ... 7 {
            #expect(BikramSambatDate.weekdayName(day, style: .transliterated) == expected[day - 1], "day \(day)")
        }
    }

    @Test("All seven days resolve end-to-end through weekday()")
    func allSevenDaysEndToEnd() {
        // 27 Sep – 3 Oct 2026 are Sunday–Saturday; Ashoj 11–17, 2083.
        let expected = ["आइत", "सोम", "मंगल", "बुध", "बिही", "शुक्र", "शनि"]
        for offset in 0 ... 6 {
            let bs = BikramSambatDate(year: 2083, month: 6, day: 11 + offset)
            #expect(bs.weekday(in: .v2) == offset + 1, "weekday of \(bs)")
            #expect(BikramSambatDate.weekdayName(offset + 1, style: .nepali) == expected[offset])
        }
    }

    @Test(arguments: [0, 8, -1, 99])
    func outOfRangeWeekdayReturnsNil(weekday: Int) {
        #expect(BikramSambatDate.weekdayName(weekday, style: .nepali) == nil)
        #expect(BikramSambatDate.weekdayName(weekday, style: .transliterated) == nil)
    }
}
