// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Dibas Sigdel
import Foundation
import Testing
import NepalKitCore

/// The public-holiday lookup, and sweeps over the bundled gazette table that
/// catch a mistyped row before a reader meets it.
struct PublicHolidayCalendarTests {
    private let calendar = PublicHolidayCalendar.gazette

    private func day(_ month: Int, _ day: Int) -> BSDay {
        BSDay(year: 2083, month: month, day: day)
    }

    @Test func newYearIsANationwideHoliday() throws {
        let holiday = try #require(calendar.holidays(on: day(1, 1)).first)
        #expect(holiday.scope == .nationwide)
        #expect(holiday.nepali == "नव वर्ष")
        #expect(calendar.isNationwideHoliday(day(1, 1)))
    }

    @Test func aDayKeepsEveryGazetteRowButOneScopeEach() {
        // 18 Baisakh is three nationwide items: Buddha Jayanti, Labour Day,
        // and Buddha Jayanti again under section 7.
        #expect(calendar.holidays(on: day(1, 18)).count == 3)
        #expect(calendar.scopes(on: day(1, 18)) == [.nationwide])
        // 13 Bhadra is Gai Jatra twice, for two different groups.
        #expect(calendar.scopes(on: day(5, 13)) == [.newarCommunity, .kathmanduValley])
        #expect(!calendar.isNationwideHoliday(day(5, 13)))
        // 19 Bhadra: nationwide first, then where Gaura is observed.
        #expect(calendar.scopes(on: day(5, 19)) == [.nationwide, .gauraRegion])
        #expect(calendar.isNationwideHoliday(day(5, 19)))
    }

    @Test func scopedHolidaysAreNotNationwide() {
        let scoped: [(BSDay, PublicHoliday.Scope)] = [
            (day(5, 29), .womenEmployees),
            (day(6, 9), .kathmanduValley),
            (day(8, 8), .sikhCommunity),
            (day(8, 17), .employeesWithDisabilities),
            (day(10, 28), .educationalInstitutions),
            (day(12, 7), .hillAndMountainDistricts),
            (day(12, 8), .taraiDistricts),
            (day(12, 23), .kathmanduValley),
        ]
        for (day, scope) in scoped {
            #expect(calendar.scopes(on: day) == [scope], "\(day)")
            #expect(!calendar.isNationwideHoliday(day), "\(day)")
        }
        // 25 Kartik is Bhai Tika for everyone and Falgunanda Jayanti for the Kirat.
        #expect(calendar.scopes(on: day(7, 25)) == [.nationwide, .kiratCommunity])
        // 15 Poush: Tamu Lhosar for everyone, Dura Mhaipru Nakuma for the Dura.
        #expect(calendar.scopes(on: day(9, 15)) == [.nationwide, .duraCommunity])
    }

    @Test func jitiyaIsOnlyForWomenWhoObserveIt() {
        // Narrower than Teej: the gazette gives Jitiya to women employees who
        // observe it, and Teej to women employees.
        #expect(calendar.scopes(on: day(6, 18)) == [.womenObservingJitiya])
        #expect(calendar.scopes(on: day(5, 29)) == [.womenEmployees])
    }

    @Test func dashainAndTiharAreNationwideThroughout() {
        let dashain = [day(6, 31)] + (1 ... 6).map { day(7, $0) }
        let tihar = (22 ... 26).map { day(7, $0) }
        for day in dashain + tihar {
            #expect(calendar.isNationwideHoliday(day), "\(day)")
        }
        #expect(!calendar.isNationwideHoliday(day(6, 30)))
        #expect(!calendar.isNationwideHoliday(day(7, 7)))
        #expect(!calendar.isNationwideHoliday(day(7, 21)))
        #expect(!calendar.isNationwideHoliday(day(7, 27)))
    }

    @Test func theTableIsTheGazetteAndNotTheWeek() throws {
        // Saturdays are the weekly holiday, which the grid draws on its own;
        // the gazette table neither adds them nor skips a holiday that falls
        // on one.
        let dataset = CalendarDataset.v2
        var saturdaysOff = 0
        var saturdaysListed = 0
        let lengths = try #require(dataset.monthLengths(for: 2083))
        for month in 1 ... 12 {
            for date in 1 ... lengths[month - 1] {
                let bs = day(month, date)
                let ad = try #require(bsToAD(bs, in: dataset))
                guard weekday(of: ad) == 7 else { continue }
                if calendar.holidays(on: bs).isEmpty { saturdaysOff += 1 } else { saturdaysListed += 1 }
            }
        }
        #expect(saturdaysOff > 40)
        #expect(saturdaysListed > 0)
    }

    @Test func aYearWithoutDataHasNone() {
        #expect(calendar.years == [2083])
        #expect(calendar.holidays(on: BSDay(year: 2082, month: 1, day: 1)).isEmpty)
        #expect(!calendar.isNationwideHoliday(BSDay(year: 2084, month: 1, day: 1)))
        #expect(calendar.scopes(on: BSDay(year: 2084, month: 1, day: 1)).isEmpty)
    }

    @Test func aCalendarIsOnlyItsEntries() {
        let holiday = PublicHoliday(scope: .sikhCommunity, nepali: "परीक्षण")
        let custom = PublicHolidayCalendar(years: [2083], entries: [day(1, 2): [holiday, holiday]])
        #expect(custom.holidays(on: day(1, 2)) == [holiday, holiday])
        #expect(custom.scopes(on: day(1, 2)) == [.sikhCommunity])
        #expect(!custom.isNationwideHoliday(day(1, 2)))
        #expect(custom.holidays(on: day(1, 1)).isEmpty)
        #expect(custom.allEntries.count == 1)
    }

    // MARK: - The bundled table

    @Test func twentyEightyThreeHasFortyOneHolidayDays() {
        #expect(calendar.allEntries.count == 41)
        #expect(calendar.allEntries.reduce(0) { $0 + $1.holidays.count } == 47)
        #expect(calendar.allEntries.filter { calendar.isNationwideHoliday($0.day) }.count == 31)
    }

    @Test func everyHolidayIsARealDayInAYearWithData() {
        var offenders: [String] = []
        for (day, _) in calendar.allEntries {
            guard calendar.years.contains(day.year) else {
                offenders.append("\(day) is outside the calendar's years")
                continue
            }
            let lengths = CalendarDataset.v2.monthLengths(for: day.year)
            if let lengths, (1 ... 12).contains(day.month), (1 ... lengths[day.month - 1]).contains(day.day) { continue }
            offenders.append("\(day) is not a day of the dataset")
        }
        #expect(offenders.isEmpty, "\(offenders)")
    }

    @Test func everyRowIsNamedCleanly() {
        let names = calendar.allEntries.flatMap(\.holidays).map(\.nepali)
        let offenders = names.filter { $0.isEmpty || $0 != $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        #expect(offenders.isEmpty, "\(offenders)")
        #expect(calendar.allEntries.allSatisfy { !$0.holidays.isEmpty })
    }

    @Test func everyHolidayDayHasAFestivalToNameIt() {
        // The day's details name a holiday through the day's festivals, so a
        // gazette day the festival table missed would show a holiday with
        // nothing to say what it is.
        let missing = calendar.allEntries.map(\.day).filter { holidayDay in
            guard FestivalCalendar.panchanga.festivals(on: holidayDay).isEmpty else { return false }
            // Dashain and Tihar's days between their named ones.
            return !calendar.isNationwideHoliday(holidayDay)
        }
        #expect(missing.isEmpty, "\(missing)")
    }

    @Test func aHolidayWithNoFestivalIsNamedByTheGazette() {
        let holidays = PublicHolidayCalendar.gazette
        let festivals = FestivalCalendar.panchanga
        // Kartik 2, 5 and 6 are Dashain holidays with no festival of their own;
        // Kartik 26 is the last day of the Tihar holiday.
        for day in [2, 5, 6] {
            let named = holidays.observances(on: BSDay(year: 2083, month: 7, day: day), festivals: festivals)
            #expect(named.map(\.nepali) == ["दशैं बिदा"])
            #expect(named.first?.english == "Dashain holiday")
            #expect(named.first?.source == .gazette)
        }
        let tihar = holidays.observances(on: BSDay(year: 2083, month: 7, day: 26), festivals: festivals)
        #expect(tihar.map(\.english) == ["Tihar holiday"])
    }

    @Test func aDayWithFestivalsKeepsThem() {
        // Kartik 4, Vijaya Dashami: the festival names the day, not "Dashain holiday".
        let day = BSDay(year: 2083, month: 7, day: 4)
        let named = PublicHolidayCalendar.gazette.observances(on: day, festivals: .panchanga)
        #expect(named == FestivalCalendar.panchanga.festivals(on: day))
        #expect(!named.contains { $0.source == .gazette && $0.english == "Dashain holiday" })
    }

    @Test func everyNationwideHolidayHasAName() {
        let holidays = PublicHolidayCalendar.gazette
        for (day, rows) in holidays.allEntries where rows.contains(where: { $0.scope == .nationwide }) {
            #expect(!holidays.observances(on: day, festivals: .panchanga).isEmpty, "\(day) is red with no name")
        }
    }
}
