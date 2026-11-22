import Testing
import NepalKitCore

struct MonthStartTests {
    static let bsToADCases: [MonthStartFixture] = [
        .init(bs: BikramSambatDate(year: 2083, month: 5, day: 1), ad: GregorianDate(year: 2026, month: 8, day: 17), label: "Bhadra 2083"),
        .init(bs: BikramSambatDate(year: 2083, month: 6, day: 1), ad: GregorianDate(year: 2026, month: 9, day: 17), label: "Ashoj 2083"),
    ]

    static let adToBSCases: [MonthStartFixture] = [
        .init(bs: BikramSambatDate(year: 2083, month: 6, day: 1), ad: GregorianDate(year: 2026, month: 9, day: 17), label: "Ashoj 2083"),
    ]

    @Test(arguments: bsToADCases)
    func publishedMonthStartBStoAD(testCase: MonthStartFixture) {
        #expect(
            GregorianDate(testCase.bs, in: .v2) == testCase.ad,
            "\(testCase.label)"
        )
    }

    @Test(arguments: adToBSCases)
    func publishedMonthStartADtoBS(testCase: MonthStartFixture) {
        #expect(
            BikramSambatDate(testCase.ad, in: .v2) == testCase.bs,
            "\(testCase.label)"
        )
    }
}
