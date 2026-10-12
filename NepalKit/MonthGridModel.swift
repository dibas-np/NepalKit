// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Dibas Sigdel
import Foundation
import Observation
import NepalKitCore

/// One Bikram Sambat month.
struct MonthGridMonth: Hashable {
    let year: Int
    let month: Int

    /// The month before, without bounds: the model checks the supported range.
    var previous: MonthGridMonth {
        month == 1 ? MonthGridMonth(year: year - 1, month: 12) : MonthGridMonth(year: year, month: month - 1)
    }

    /// The month after, without bounds.
    var next: MonthGridMonth {
        month == 12 ? MonthGridMonth(year: year + 1, month: 1) : MonthGridMonth(year: year, month: month + 1)
    }
}

/// One filled cell of the month grid: a Bikram Sambat day, the Gregorian day it
/// falls on, and its weekday, which belongs to the civil day and not to either
/// calendar (CONTEXT.md, *Weekday*).
struct MonthGridDay: Hashable {
    let bikramSambat: BSDay
    let gregorian: GADay
    /// 1 (Sunday) through 7 (Saturday), as the core reports it.
    let weekday: Int
    /// Only ever true inside the shown month: a neighbouring month's
    /// spill-over is context.
    let isToday: Bool
    /// False for the neighbouring months' days filling the first and last
    /// weeks, which the view dims and leaves out of VoiceOver and taps.
    let isInShownMonth: Bool
    /// The festivals and national days on this day, in the Panchanga's order;
    /// empty for a year whose Panchanga has not been read (ADR-0016).
    let festivals: [Festival]
    /// Who the gazette makes this day a holiday for, one entry per scope;
    /// empty for a working day or a year whose notice has not been read.
    let holidayScopes: [PublicHoliday.Scope]

    /// Saturday (शनिबार), Nepal's weekly public holiday, which wall calendars
    /// print in red.
    static let weeklyHolidayWeekday = 7

    var isWeeklyHoliday: Bool { weekday == Self.weeklyHolidayWeekday }

    var isNationwideHoliday: Bool { holidayScopes.contains(.nationwide) }

    /// Whether the day number is red, as a wall calendar prints it. A limited
    /// holiday (one community or region) stays black, since most readers work
    /// that day; the day's details say who it is for.
    var isMarkedAsHoliday: Bool { isWeeklyHoliday || isNationwideHoliday }

    /// Only inside the shown month, like `isToday`: a mark on a neighbouring
    /// month's day would read as this month's.
    var showsFestivalMark: Bool { isInShownMonth && !festivals.isEmpty }
}

/// The month grid's state: the shown month, bounded navigation through the
/// supported range, and the grid of weeks.
///
/// Session-scoped like `ConverterModel`: the popover's content closure captures
/// it once, so today can go stale across a midnight. The view calls
/// `refreshToday(now:)` on appear, which moves the today marking but not the
/// shown month. Midnight is in `timeZone`, Nepal Time unless the user chose
/// their own (ADR-0017).
@MainActor
@Observable
final class MonthGridModel {
    /// Only changed through the bounded navigation, so always in range.
    private(set) var shown: MonthGridMonth

    /// Today in `timeZone` as a Bikram Sambat date, or nil past the supported range.
    private(set) var today: BSDay?

    /// Today's Gregorian day, for distances from today. Kept beside `today`
    /// because it survives the range boundary, where the Bikram Sambat side
    /// does not.
    private(set) var todayGregorian: GADay?

    /// Today is past the dataset's last day, so the grid opens on the last
    /// supported month and the view says why.
    private(set) var isTodayPastSupportedRange: Bool

    /// The zone today is read in.
    private(set) var timeZone: TimeZone

    private let dataset: CalendarDataset
    private let festivalCalendar: FestivalCalendar
    private let holidayCalendar: PublicHolidayCalendar

    /// Gesture state for scroll paging. Not observed: it never draws.
    @ObservationIgnored private var scrollPager = MonthScrollPager()

    /// - Parameters:
    ///   - festivals: the days' festivals; injected so a test can mark its own.
    ///   - holidays: the days' public holidays, injected for the same reason.
    ///   - now: the instant today is read from; injected for tests and previews.
    ///   - timeZone: the zone today is read in; the app passes the user's
    ///     time reference and moves it with `setTimeZone(_:now:)`.
    init(dataset: CalendarDataset = AppData.dataset, festivals: FestivalCalendar = .panchanga,
         holidays: PublicHolidayCalendar = .gazette, now: Date = .now, timeZone: TimeZone = nepalTimeZone) {
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

    // MARK: - Navigation

    private var first: MonthGridMonth { MonthGridMonth(year: dataset.supportedRange.lowerBound, month: 1) }
    private var last: MonthGridMonth { MonthGridMonth(year: dataset.supportedRange.upperBound, month: 12) }

    var canShowPreviousMonth: Bool { shown != first }
    var canShowNextMonth: Bool { shown != last }

    /// Whether "Today" would return to the shown month, so it can be disabled.
    var isShowingTodayMonth: Bool { shown == Self.month(containing: today, in: dataset, pastRange: isTodayPastSupportedRange) }

    func showPreviousMonth() {
        guard canShowPreviousMonth else { return }
        shown = shown.previous
    }

    func showNextMonth() {
        guard canShowNextMonth else { return }
        shown = shown.next
    }

    /// Moves one month in the step's direction. Arrow keys and scrolling page
    /// through here, so they stop where the chevrons do.
    func page(by step: Int) {
        if step > 0 { showNextMonth() } else if step < 0 { showPreviousMonth() }
    }

    /// One scroll event over the grid; pages when the gesture has travelled
    /// far enough (`MonthScrollPager`).
    func scroll(deltaY: Double, phase: MonthScrollPager.Phase) {
        page(by: scrollPager.step(deltaY: deltaY, phase: phase))
    }

    /// Re-reads today and returns to its month (the last supported month past
    /// the range).
    func showToday(now: Date) {
        refreshToday(now: now)
        shown = Self.month(containing: today, in: dataset, pastRange: isTodayPastSupportedRange)
    }

    /// Re-reads today without moving the shown month. Assigns only what
    /// changed, so an unchanged day does not invalidate observers.
    func refreshToday(now: Date) {
        let state = Self.todayState(now: now, timeZone: timeZone, in: dataset)
        if today != state.today { today = state.today }
        if todayGregorian != state.todayAD { todayGregorian = state.todayAD }
        if isTodayPastSupportedRange != state.isPastRange { isTodayPastSupportedRange = state.isPastRange }
    }

    /// Reads today in another zone; only the today marking moves.
    func setTimeZone(_ timeZone: TimeZone, now: Date) {
        self.timeZone = timeZone
        refreshToday(now: now)
    }

    /// One reading of today, so `init` and `refreshToday` cannot disagree.
    private struct TodayState {
        let today: BSDay?
        let todayAD: GADay?
        let isPastRange: Bool
    }

    private static func todayState(now: Date, timeZone: TimeZone, in dataset: CalendarDataset) -> TodayState {
        let today = todayBS(now: now, timeZone: timeZone, in: dataset)
        let todayGregorian = todayAD(now: now, timeZone: timeZone)
        var isPastRange = false
        if today == nil, let todayGregorian, let end = dataset.gregorianEnd {
            isPastRange = todayGregorian > end
        }
        return TodayState(today: today, todayAD: todayGregorian, isPastRange: isPastRange)
    }

    /// Today's month, else the range's last month past it, else its first: a
    /// today before the range is unreachable with this dataset but must not trap.
    private static func month(containing today: BSDay?, in dataset: CalendarDataset, pastRange: Bool) -> MonthGridMonth {
        if let today { return MonthGridMonth(year: today.year, month: today.month) }
        return pastRange
            ? MonthGridMonth(year: dataset.supportedRange.upperBound, month: 12)
            : MonthGridMonth(year: dataset.supportedRange.lowerBound, month: 1)
    }

    // MARK: - Grid

    /// Weeks the grid always draws: the most a month can need (a 32-day month
    /// starting on Saturday), so the popover's height holds still while
    /// scrolling pages months under the pointer.
    static let weekCount = 6

    /// The shown month as `weekCount` Sunday-first (आइतबार, the core's weekday
    /// 1) weeks, padded with neighbouring months' days as a wall calendar is.
    /// A nil cell is outside the dataset, with no Bikram Sambat date.
    var weeks: [[MonthGridDay?]] {
        let length = monthLength(shown)
        let firstBS = BSDay(year: shown.year, month: shown.month, day: 1)
        // Every day of a supported month converts; the dataset's own init
        // validates the table this walks.
        guard let firstAD = bsToAD(firstBS, in: dataset), let firstWeekday = weekday(of: firstAD) else {
            preconditionFailure("Supported BS day \(firstBS) did not convert")
        }
        let leading = firstWeekday - 1
        let previous = canShowPreviousMonth ? shown.previous : nil
        let next = canShowNextMonth ? shown.next : nil
        let cells: [MonthGridDay?] = (0 ..< Self.weekCount * 7).map { index in
            // Day of the shown month this cell would be, counting past both
            // ends: 0 is the previous month's last day, length + 1 the next
            // month's first.
            let offset = index - leading + 1
            let bs: BSDay?
            if offset < 1 {
                bs = previous.map { BSDay(year: $0.year, month: $0.month, day: monthLength($0) + offset) }
            } else if offset > length {
                bs = next.map { BSDay(year: $0.year, month: $0.month, day: offset - length) }
            } else {
                bs = BSDay(year: shown.year, month: shown.month, day: offset)
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

    /// Days in a supported month. Callers pass only months inside the range.
    private func monthLength(_ month: MonthGridMonth) -> Int {
        guard let lengths = dataset.monthLengths(for: month.year) else {
            preconditionFailure("Validated dataset is missing the month lengths for BS year \(month.year)")
        }
        return lengths[month.month - 1]
    }

    // MARK: - Text

    /// "Baisakh 2082", honouring both display settings.
    func title(settings: DisplaySettings) -> String {
        "\(monthName(month: shown.month, style: settings.monthNames)) \(formatNumber(shown.year, digits: settings.digits))"
    }

    /// The Gregorian months the shown month spans: "Oct–Nov 2026", or
    /// "Dec 2026 – Jan 2027". Short names, as the header shares its row with
    /// three buttons.
    func gregorianSpan(settings: DisplaySettings) -> String? {
        guard let (first, last) = gregorianBounds() else { return nil }
        let short = { (month: Int) in String(gregorianMonthName(month).prefix(3)) }
        let year = { (year: Int) in formatNumber(year, digits: settings.digits) }
        if first.year != last.year {
            return "\(short(first.month)) \(year(first.year)) – \(short(last.month)) \(year(last.year))"
        }
        if first.month != last.month {
            return "\(short(first.month))–\(short(last.month)) \(year(first.year))"
        }
        return "\(short(first.month)) \(year(first.year))"
    }

    /// The span as spoken: full month names and Latin digits.
    func spokenGregorianSpan() -> String? {
        guard let (first, last) = gregorianBounds() else { return nil }
        let name = gregorianMonthName
        if first.year != last.year {
            return "\(name(first.month)) \(first.year) to \(name(last.month)) \(last.year)"
        }
        if first.month != last.month {
            return "\(name(first.month)) to \(name(last.month)) \(first.year)"
        }
        return "\(name(first.month)) \(first.year)"
    }

    private func gregorianBounds() -> (GADay, GADay)? {
        guard let length = dataset.monthLengths(for: shown.year)?[shown.month - 1],
              let first = bsToAD(BSDay(year: shown.year, month: shown.month, day: 1), in: dataset),
              let last = bsToAD(BSDay(year: shown.year, month: shown.month, day: length), in: dataset)
        else { return nil }
        return (first, last)
    }

    /// The title as spoken: the month name in the user's setting, the year in
    /// Latin digits (`SpokenDate`'s rule).
    func spokenTitle(settings: DisplaySettings) -> String {
        "\(monthName(month: shown.month, style: settings.monthNames)) \(SpokenDate.number(shown.year))"
    }

    /// The weekday header, Sunday first, in short forms: seven full names do
    /// not fit a 340pt popover.
    func weekdayHeaders(settings: DisplaySettings) -> [String] {
        (1 ... 7).map { Self.shortWeekdayName($0, style: settings.monthNames) }
    }

    /// Full weekday names for the header's spoken channel.
    func spokenWeekdayHeaders(settings: DisplaySettings) -> [String] {
        (1 ... 7).map { weekdayName(for: $0, style: settings.monthNames) ?? "" }
    }

    /// Whether header column `column` (0 is Sunday) is the weekly holiday's.
    func isWeeklyHolidayColumn(_ column: Int) -> Bool {
        column + 1 == MonthGridDay.weeklyHolidayWeekday
    }

    /// The menu bar's weekday uses the same short forms, so the cut lives in
    /// core (`shortWeekdayName(for:style:)`) rather than here.
    static func shortWeekdayName(_ weekday: Int, style: MonthNameStyle) -> String {
        NepalKitCore.shortWeekdayName(for: weekday, style: style) ?? ""
    }

    /// The cell's large Bikram Sambat day number.
    func dayText(_ day: MonthGridDay, settings: DisplaySettings) -> String {
        formatNumber(day.bikramSambat.day, digits: settings.digits)
    }

    /// The cell's small Gregorian day number.
    func gregorianDayText(_ day: MonthGridDay, settings: DisplaySettings) -> String {
        formatNumber(day.gregorian.day, digits: settings.digits)
    }

    /// The cell's spoken label: both full dates and the weekday, so a cell
    /// read out of context names its day, then what its mark and red stand for.
    func spokenLabel(for day: MonthGridDay, settings: DisplaySettings) -> String {
        let parts = [
            day.isToday ? Strings.todayLabel : nil,
            SpokenDate.bs(day.bikramSambat, monthNames: settings.monthNames),
            weekdayName(for: day.weekday, style: settings.monthNames),
            SpokenDate.ad(day.gregorian),
        ] + day.festivals.map { SpokenDate.festival($0, monthNames: settings.monthNames) }
            + day.holidayScopes.map { Strings.publicHolidaySpoken($0, monthNames: settings.monthNames) }
        return parts.compactMap { $0 }.joined(separator: ", ")
    }

    /// The shown year's caveats: provisional, or missing from the festival or
    /// holiday list. A list with no years says nothing, having no year to name.
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

    /// Last supported Bikram Sambat year, named in the range boundary state.
    var lastSupportedBSYear: Int { dataset.supportedRange.upperBound }
}
