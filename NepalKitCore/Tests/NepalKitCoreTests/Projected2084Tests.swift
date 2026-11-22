// SPDX-License-Identifier: MIT
// Copyright (C) 2026 Dibas Sigdel
import Testing
import NepalKitCore

struct Projected2084Tests {
    static let monthStarts: [MonthStartFixture] = [
        .init(bs: BikramSambatDate(year: 2084, month: 1, day: 1), ad: GregorianDate(year: 2027, month: 4, day: 14), label: "Baisakh"),
        .init(bs: BikramSambatDate(year: 2084, month: 2, day: 1), ad: GregorianDate(year: 2027, month: 5, day: 15), label: "Jestha"),
        .init(bs: BikramSambatDate(year: 2084, month: 3, day: 1), ad: GregorianDate(year: 2027, month: 6, day: 16), label: "Ashar"),
        .init(bs: BikramSambatDate(year: 2084, month: 4, day: 1), ad: GregorianDate(year: 2027, month: 7, day: 17), label: "Shrawan"),
        .init(bs: BikramSambatDate(year: 2084, month: 5, day: 1), ad: GregorianDate(year: 2027, month: 8, day: 18), label: "Bhadra"),
        .init(bs: BikramSambatDate(year: 2084, month: 6, day: 1), ad: GregorianDate(year: 2027, month: 9, day: 18), label: "Ashoj"),
        .init(bs: BikramSambatDate(year: 2084, month: 7, day: 1), ad: GregorianDate(year: 2027, month: 10, day: 18), label: "Kartik"),
        .init(bs: BikramSambatDate(year: 2084, month: 8, day: 1), ad: GregorianDate(year: 2027, month: 11, day: 17), label: "Mangsir"),
        .init(bs: BikramSambatDate(year: 2084, month: 9, day: 1), ad: GregorianDate(year: 2027, month: 12, day: 17), label: "Poush"),
        .init(bs: BikramSambatDate(year: 2084, month: 10, day: 1), ad: GregorianDate(year: 2028, month: 1, day: 15), label: "Magh"),
        .init(bs: BikramSambatDate(year: 2084, month: 11, day: 1), ad: GregorianDate(year: 2028, month: 2, day: 13), label: "Falgun"),
        .init(bs: BikramSambatDate(year: 2084, month: 12, day: 1), ad: GregorianDate(year: 2028, month: 3, day: 14), label: "Chaitra"),
    ]

    @Test(arguments: monthStarts)
    func provisionalMonthStartBothDirections(testCase: MonthStartFixture) {
        #expect(GregorianDate(testCase.bs, in: .v2) == testCase.ad)
        #expect(BikramSambatDate(testCase.ad, in: .v2) == testCase.bs)
    }

    @Test func birthdayMappingBothDirections() {
        let birthday = BikramSambatDate(year: 2084, month: 5, day: 22)
        let gregorian = GregorianDate(year: 2027, month: 9, day: 8)
        #expect(GregorianDate(birthday, in: .v2) == gregorian)
        #expect(BikramSambatDate(gregorian, in: .v2) == birthday)
    }

    @Test func revisedMonthEndsAndInvalidDays() {
        #expect(GregorianDate(BikramSambatDate(year: 2084, month: 2, day: 32), in: .v2) == GregorianDate(year: 2027, month: 6, day: 15))
        #expect(GregorianDate(BikramSambatDate(year: 2084, month: 3, day: 32), in: .v2) == nil)
        #expect(GregorianDate(BikramSambatDate(year: 2084, month: 4, day: 32), in: .v2) == GregorianDate(year: 2027, month: 8, day: 17))
        #expect(GregorianDate(BikramSambatDate(year: 2084, month: 10, day: 30), in: .v2) == nil)
        #expect(GregorianDate(BikramSambatDate(year: 2084, month: 12, day: 31), in: .v2) == nil)
    }

    @Test func unchangedSupportedBoundsAndRevisedVersion() {
        #expect(CalendarDataset.v2.version == "2.0.1")
        #expect(CalendarDataset.v2.gregorianStart == GregorianDate(year: 1918, month: 4, day: 13))
        #expect(CalendarDataset.v2.gregorianEnd == GregorianDate(year: 2028, month: 4, day: 12))
        #expect(BikramSambatDate(GregorianDate(year: 2028, month: 4, day: 13), in: .v2) == nil)
    }

    @Test("Only the projected 2084 row is provisional")
    func onlyTheProjectedRowIsProvisional() {
        #expect(CalendarDataset.v2.provisionalYears == [2084])
        #expect(CalendarDataset.v2.isProvisional(2084))
        #expect(!CalendarDataset.v2.isProvisional(2083))
    }

    @Test("Range bounds: the first year is attested, years outside the table are not provisional")
    func provisionalFlagAtTheRangeBounds() {
        #expect(!CalendarDataset.v2.isProvisional(1975))
        #expect(!CalendarDataset.v2.isProvisional(1974))
        #expect(!CalendarDataset.v2.isProvisional(2085))
    }

    @Test("A provisional year outside the supported range is dropped, not named")
    func provisionalYearsAreClippedToTheRange() {
        let v2 = CalendarDataset.v2
        let dataset = CalendarDataset(
            version: "test", years: v2.years, anchorBikramSambat: v2.anchorBikramSambat, anchorGregorian: v2.anchorGregorian,
            supportedRange: v2.supportedRange, provisionalYears: [2084, 2085]
        )
        #expect(dataset.provisionalYears == [2084])
        #expect(!dataset.isProvisional(2085))
    }
}
