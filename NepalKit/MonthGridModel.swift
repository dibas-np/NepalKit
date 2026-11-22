// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Dibas Sigdel
import Foundation
import Observation
import NepalKitCore

struct MonthGridMonth: Hashable {
    let year: Int
    let month: Int

    var previous: MonthGridMonth {
        month == 1 ? MonthGridMonth(year: year - 1, month: 12) : MonthGridMonth(year: year, month: month - 1)
    }

    var next: MonthGridMonth {
        month == 12 ? MonthGridMonth(year: year + 1, month: 1) : MonthGridMonth(year: year, month: month + 1)
    }
}

struct MonthGridDay: Hashable {
    let bikramSambat: BikramSambatDate
    let gregorian: GregorianDate
    let weekday: Int
    let isToday: Bool
    let isInShownMonth: Bool
    let festivals: [Festival]
    let holidayScopes: [PublicHoliday.Scope]

    static let weeklyHolidayWeekday = 7

    var isWeeklyHoliday: Bool { weekday == Self.weeklyHolidayWeekday }

    var isNationwideHoliday: Bool { holidayScopes.contains(.nationwide) }

    var isMarkedAsHoliday: Bool { isWeeklyHoliday || isNationwideHoliday }

    var showsFestivalMark: Bool { isInShownMonth && !festivals.isEmpty }
}

@MainActor
@Observable
final class MonthGridModel {
    private(set) var shown: MonthGridMonth

    private(set) var today: BikramSambatDate?

    private(set) var todayGregorian: GregorianDate?

    private(set) var isTodayPastSupportedRange: Bool

    private(set) var timeZone: TimeZone

    private let dataset: CalendarDataset
    private let festivalCalendar: FestivalCalendar
    private let holidayCalendar: PublicHolidayCalendar

    @ObservationIgnored private var scrollPager = MonthScrollPager()

    init(dataset: CalendarDataset = AppData.dataset, festivals: FestivalCalendar = .panchanga,
         holidays: PublicHolidayCalendar = .gazette, now: Date = .now, timeZone: TimeZone = .nepal) {
        self.dataset = dataset
        self.festivalCalendar = festivals
        self.holidayCalendar = holidays
        self.timeZone = timeZone
        let state = Self.todayState(now: now, timeZone: timeZone, in: dataset)
        self.today = state.today
        self.todayGregorian = state.todayAD
        self.isTodayPastSupportedRange = state.isPastRange
        self.shown = Self.month(containing: state.today, in: dataset, pastRange: state.isPastRange)
    }

    private var first: MonthGridMonth { MonthGridMonth(year: dataset.supportedRange.lowerBound, month: 1) }
    private var last: MonthGridMonth { MonthGridMonth(year: dataset.supportedRange.upperBound, month: 12) }

    var canShowPreviousMonth: Bool { shown != first }
    var canShowNextMonth: Bool { shown != last }

    var isShowingTodayMonth: Bool { shown == Self.month(containing: today, in: dataset, pastRange: isTodayPastSupportedRange) }

    func showPreviousMonth() {
        guard canShowPreviousMonth else { return }
        shown = shown.previous
    }

    func showNextMonth() {
        guard canShowNextMonth else { return }
        shown = shown.next
    }

    func page(by step: Int) {
        if step > 0 { showNextMonth() } else if step < 0 { showPreviousMonth() }
    }

    func scroll(deltaY: Double, phase: MonthScrollPager.Phase) {
        page(by: scrollPager.step(deltaY: deltaY, phase: phase))
    }

    func showToday(now: Date) {
        refreshToday(now: now)
        shown = Self.month(containing: today, in: dataset, pastRange: isTodayPastSupportedRange)
    }

    func refreshToday(now: Date) {
        let state = Self.todayState(now: now, timeZone: timeZone, in: dataset)
        if today != state.today { today = state.today }
        if todayGregorian != state.todayAD { todayGregorian = state.todayAD }
        if isTodayPastSupportedRange != state.isPastRange { isTodayPastSupportedRange = state.isPastRange }
    }

    func setTimeZone(_ timeZone: TimeZone, now: Date) {
        self.timeZone = timeZone
        refreshToday(now: now)
    }

    private struct TodayState {
        let today: BikramSambatDate?
        let todayAD: GregorianDate?
        let isPastRange: Bool
    }

    private static func todayState(now: Date, timeZone: TimeZone, in dataset: CalendarDataset) -> TodayState {
        let today = BikramSambatDate.today(now: now, timeZone: timeZone, in: dataset)
        let todayGregorian = GregorianDate.today(now: now, timeZone: timeZone)
        var isPastRange = false
        if today == nil, let todayGregorian, let end = dataset.gregorianEnd {
            isPastRange = todayGregorian > end
        }
        return TodayState(today: today, todayAD: todayGregorian, isPastRange: isPastRange)
    }

    private static func month(containing today: BikramSambatDate?, in dataset: CalendarDataset, pastRange: Bool) -> MonthGridMonth {
        if let today { return MonthGridMonth(year: today.year, month: today.month) }
        return pastRange
            ? MonthGridMonth(year: dataset.supportedRange.upperBound, month: 12)
            : MonthGridMonth(year: dataset.supportedRange.lowerBound, month: 1)
    }

    static let weekCount = 6

    var weeks: [[MonthGridDay?]] {
        let length = monthLength(shown)
        let firstBS = BikramSambatDate(year: shown.year, month: shown.month, day: 1)
        guard let firstAD = GregorianDate(firstBS, in: dataset), let firstWeekday = firstAD.weekday else {
            preconditionFailure("Supported BS day \(firstBS) did not convert")
        }
        let leading = firstWeekday - 1
        let previous = canShowPreviousMonth ? shown.previous : nil
        let next = canShowNextMonth ? shown.next : nil
        let cells: [MonthGridDay?] = (0 ..< Self.weekCount * 7).map { index in
            let offset = index - leading + 1
            let bs: BikramSambatDate?
            if offset < 1 {
                bs = previous.map { BikramSambatDate(year: $0.year, month: $0.month, day: monthLength($0) + offset) }
            } else if offset > length {
                bs = next.map { BikramSambatDate(year: $0.year, month: $0.month, day: offset - length) }
            } else {
                bs = BikramSambatDate(year: shown.year, month: shown.month, day: offset)
            }
            guard let bs, let ad = firstAD.advanced(byDays: offset - 1) else { return nil }
            let inShownMonth = (1 ... length).contains(offset)
            return MonthGridDay(
                bikramSambat: bs, gregorian: ad, weekday: index % 7 + 1,
                isToday: inShownMonth && bs == today, isInShownMonth: inShownMonth,
                festivals: holidayCalendar.observances(on: bs, festivals: festivalCalendar), holidayScopes: holidayCalendar.scopes(on: bs)
            )
        }
        return stride(from: 0, to: cells.count, by: 7).map { Array(cells[$0 ..< $0 + 7]) }
    }

    private func monthLength(_ month: MonthGridMonth) -> Int {
        guard let lengths = dataset.monthLengths(for: month.year) else {
            preconditionFailure("Validated dataset is missing the month lengths for BS year \(month.year)")
        }
        return lengths[month.month - 1]
    }

    func title(settings: DisplaySettings) -> String {
        "\(BikramSambatDate.monthName(shown.month, style: settings.monthNames)) \(settings.digits.format(shown.year))"
    }

    func gregorianSpan(settings: DisplaySettings) -> String? {
        guard let (first, last) = gregorianBounds() else { return nil }
        let short = { (month: Int) in String(GregorianDate.monthName(month).prefix(3)) }
        let year = { (year: Int) in settings.digits.format(year) }
        if first.year != last.year {
            return "\(short(first.month)) \(year(first.year)) – \(short(last.month)) \(year(last.year))"
        }
        if first.month != last.month {
            return "\(short(first.month))–\(short(last.month)) \(year(first.year))"
        }
        return "\(short(first.month)) \(year(first.year))"
    }

    func spokenGregorianSpan() -> String? {
        guard let (first, last) = gregorianBounds() else { return nil }
        let name = GregorianDate.monthName
        if first.year != last.year {
            return "\(name(first.month)) \(first.year) to \(name(last.month)) \(last.year)"
        }
        if first.month != last.month {
            return "\(name(first.month)) to \(name(last.month)) \(first.year)"
        }
        return "\(name(first.month)) \(first.year)"
    }

    private func gregorianBounds() -> (GregorianDate, GregorianDate)? {
        guard let length = dataset.monthLengths(for: shown.year)?[shown.month - 1],
              let first = GregorianDate(BikramSambatDate(year: shown.year, month: shown.month, day: 1), in: dataset),
              let last = GregorianDate(BikramSambatDate(year: shown.year, month: shown.month, day: length), in: dataset)
        else { return nil }
        return (first, last)
    }

    func spokenTitle(settings: DisplaySettings) -> String {
        "\(BikramSambatDate.monthName(shown.month, style: settings.monthNames)) \(SpokenDate.number(shown.year))"
    }

    func weekdayHeaders(settings: DisplaySettings) -> [String] {
        (1 ... 7).map { Self.shortWeekdayName($0, style: settings.monthNames) }
    }

    func spokenWeekdayHeaders(settings: DisplaySettings) -> [String] {
        (1 ... 7).map { BikramSambatDate.weekdayName($0, style: settings.monthNames) ?? "" }
    }

    func isWeeklyHolidayColumn(_ column: Int) -> Bool {
        column + 1 == MonthGridDay.weeklyHolidayWeekday
    }

    static func shortWeekdayName(_ weekday: Int, style: MonthNameStyle) -> String {
        BikramSambatDate.shortWeekdayName(weekday, style: style) ?? ""
    }

    func dayText(_ day: MonthGridDay, settings: DisplaySettings) -> String {
        settings.digits.format(day.bikramSambat.day)
    }

    func gregorianDayText(_ day: MonthGridDay, settings: DisplaySettings) -> String {
        settings.digits.format(day.gregorian.day)
    }

    func spokenLabel(for day: MonthGridDay, settings: DisplaySettings) -> String {
        let parts = [
            day.isToday ? Strings.todayLabel : nil,
            SpokenDate.bikramSambat(day.bikramSambat, monthNames: settings.monthNames),
            BikramSambatDate.weekdayName(day.weekday, style: settings.monthNames),
            SpokenDate.gregorian(day.gregorian),
        ] + day.festivals.map { SpokenDate.festival($0, monthNames: settings.monthNames) }
            + day.holidayScopes.map { Strings.publicHolidaySpoken($0, monthNames: settings.monthNames) }
        return parts.compactMap { $0 }.joined(separator: ", ")
    }

    func yearNotes(digits: DigitScript) -> [String] {
        let year = shown.year
        let festivals = festivalCalendar.years
        let holidays = holidayCalendar.years
        let lacksFestivals = !festivals.isEmpty && !festivals.contains(year)
        let lacksHolidays = !holidays.isEmpty && !holidays.contains(year)
        let listNote: String? = switch (lacksFestivals, lacksHolidays) {
        case (true, true) where festivals == holidays:
            Strings.festivalsAndHolidaysListedOnly(for: festivals, digits: digits)
        case (true, true):
            "\(Strings.festivalsListedOnly(for: festivals, digits: digits)) \(Strings.holidaysListedOnly(for: holidays, digits: digits))"
        case (true, false): Strings.festivalsListedOnly(for: festivals, digits: digits)
        case (false, true): Strings.holidaysListedOnly(for: holidays, digits: digits)
        case (false, false): nil
        }
        return [dataset.isProvisional(year) ? Strings.monthGridProvisionalYear(year, digits: digits) : nil, listNote]
            .compactMap { $0 }
    }

    var lastSupportedBSYear: Int { dataset.supportedRange.upperBound }
}
