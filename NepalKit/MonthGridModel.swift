// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Dibas Sigdel
import Foundation
import Observation
import NepalKitCore

/// One Bikram Sambat month as the month grid draws it: the year and month, and
/// its days laid out in Sunday-first weeks.
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
    /// Only ever true inside the shown month: today showing as a neighbouring
    /// month's spill-over is context, not the month the reader is looking at.
    let isToday: Bool
    /// False for the neighbouring months' days that fill the first and last
    /// weeks. The view dims them and leaves them out of VoiceOver and taps.
    let isInShownMonth: Bool
    /// The festivals and national days on this day, in the Panchanga's order;
    /// empty for a year whose Panchanga has not been read (ADR-0016).
    let festivals: [Festival]
    /// Who the gazette makes this day a holiday for, one entry per scope;
    /// empty for a working day or a year whose notice has not been read.
    let holidayScopes: [PublicHoliday.Scope]

    /// Saturday (शनिबार) is Nepal's weekly public holiday, and Nepali wall
    /// calendars print its column in red; the grid follows them so the week
    /// reads the way a reader there already knows it.
    static let weeklyHolidayWeekday = 7

    /// Whether this day falls in the holiday column.
    var isWeeklyHoliday: Bool { weekday == Self.weeklyHolidayWeekday }

    /// Whether the gazette makes this day a holiday for everyone.
    var isNationwideHoliday: Bool { holidayScopes.contains(.nationwide) }

    /// Whether the day number is red: a wall calendar prints a nationwide
    /// public holiday in the Saturday red. A limited holiday (one community,
    /// one region) stays black there, since most readers work that day; the
    /// day's details say who it is for.
    var isMarkedAsHoliday: Bool { isWeeklyHoliday || isNationwideHoliday }

    /// Whether the cell carries the festival mark. Only inside the shown
    /// month, for the same reason today is: a neighbouring month's day is
    /// context, and a mark on it would read as this month's.
    var showsFestivalMark: Bool { isInShownMonth && !festivals.isEmpty }
}

/// Owns the month grid's state: which Bikram Sambat month is shown, the bounded
/// navigation through the supported range, and the grid of weeks.
///
/// Session-scoped like `ConverterModel` and for the same reason: the popover's
/// content closure captures it once. That makes today a value that can go stale
/// across a Nepal Time midnight, so the view calls `refreshToday(now:)` each
/// time it appears; that moves the today marking without moving the month the
/// user navigated to.
@MainActor
@Observable
final class MonthGridModel {
    /// The shown month. Only changed through the bounded navigation below, so it
    /// is always inside the supported range.
    private(set) var shown: MonthGridMonth

    /// Today in Nepal Time as a Bikram Sambat date, or nil past the supported range.
    private(set) var today: BSDay?

    /// Today's Nepal Time Gregorian day, which a day's distance from today is
    /// counted from. Kept beside `today` because it survives the range
    /// boundary, where the Bikram Sambat side does not.
    private(set) var todayGregorian: GADay?

    /// True when today's Nepal Time date is later than the last day the dataset
    /// covers. The range boundary state: today's month cannot be shown, so the
    /// grid opens on the last supported month and the view says why.
    private(set) var isTodayPastSupportedRange: Bool

    private let dataset: CalendarDataset
    private let festivalCalendar: FestivalCalendar
    private let holidayCalendar: PublicHolidayCalendar

    /// Gesture state for scroll paging. Not observed: it never draws.
    @ObservationIgnored private var scrollPager = MonthScrollPager()

    /// - Parameters:
    ///   - festivals: the days' festivals; injected so a test can mark its own.
    ///   - holidays: the days' public holidays, injected for the same reason.
    ///   - now: the instant today is read from. Injected so a test or a
    ///     preview does not depend on the day it runs.
    init(dataset: CalendarDataset = AppData.dataset, festivals: FestivalCalendar = .panchanga,
         holidays: PublicHolidayCalendar = .gazette, now: Date = .now) {
        self.dataset = dataset
        self.festivalCalendar = festivals
        self.holidayCalendar = holidays
        let state = Self.todayState(now: now, in: dataset)
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

    /// Whether the shown month already is the one "Today" would return to, so
    /// the control can be disabled instead of doing nothing.
    var isShowingTodayMonth: Bool { shown == Self.month(containing: today, in: dataset, pastRange: isTodayPastSupportedRange) }

    func showPreviousMonth() {
        guard canShowPreviousMonth else { return }
        shown = shown.previous
    }

    func showNextMonth() {
        guard canShowNextMonth else { return }
        shown = shown.next
    }

    /// Moves one month forward for a positive step and back for a negative
    /// one, within the supported range. The arrow keys and scrolling page
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

    /// Re-reads today without moving the shown month, so the today marking and
    /// the range boundary state are current when the popover reopens.
    func refreshToday(now: Date) {
        let state = Self.todayState(now: now, in: dataset)
        if today != state.today { today = state.today }
        if todayGregorian != state.todayAD { todayGregorian = state.todayAD }
        if isTodayPastSupportedRange != state.isPastRange { isTodayPastSupportedRange = state.isPastRange }
    }

    /// Today as the model reads it, in one value so `init` and
    /// `refreshToday` cannot read it two different ways.
    private struct TodayState {
        let today: BSDay?
        let todayAD: GADay?
        let isPastRange: Bool
    }

    private static func todayState(now: Date, in dataset: CalendarDataset) -> TodayState {
        let today = todayBS(now: now, in: dataset)
        let todayGregorian = todayAD(now: now)
        var isPastRange = false
        if today == nil, let todayGregorian, let end = dataset.gregorianEnd {
            isPastRange = todayGregorian > end
        }
        return TodayState(today: today, todayAD: todayGregorian, isPastRange: isPastRange)
    }

    /// Today's month, else the supported range's last month past it, else its
    /// first: a today before the range is not reachable with this dataset, but
    /// it must still open on a real month rather than trap.
    private static func month(containing today: BSDay?, in dataset: CalendarDataset, pastRange: Bool) -> MonthGridMonth {
        if let today { return MonthGridMonth(year: today.year, month: today.month) }
        return pastRange
            ? MonthGridMonth(year: dataset.supportedRange.upperBound, month: 12)
            : MonthGridMonth(year: dataset.supportedRange.lowerBound, month: 1)
    }

    // MARK: - Grid

    /// Weeks the grid always draws. Six is the most a month can need (a
    /// 32-day month starting on Saturday), and drawing six for every month
    /// keeps the popover's height still while the reader pages through months,
    /// which matters now that a scroll can change the month under the pointer.
    static let weekCount = 6

    /// The shown month as `weekCount` Sunday-first weeks of seven cells. The
    /// first and last weeks are filled with the neighbouring months' days
    /// (`isInShownMonth` false), as a wall calendar fills them. A nil cell is a
    /// day before the dataset's first or after its last, which has no Bikram
    /// Sambat date to show. Nepali wall calendars start the week on Sunday
    /// (आइतबार), which is also the core's weekday 1.
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

    /// The Gregorian months the shown month spans, beside its title:
    /// "Oct–Nov 2026", or "Dec 2026 – Jan 2027" across a year end. Short
    /// month names, because the header shares its row with three buttons.
    /// Nil only if the table cannot place the month.
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

    /// The weekday header, Sunday first. English names are cut to three letters
    /// because seven full names do not fit a 340pt popover; the Nepali names are
    /// already short forms.
    func weekdayHeaders(settings: DisplaySettings) -> [String] {
        (1 ... 7).map { Self.shortWeekdayName($0, style: settings.monthNames) }
    }

    /// Full weekday names for the header's spoken channel.
    func spokenWeekdayHeaders(settings: DisplaySettings) -> [String] {
        (1 ... 7).map { weekdayName(for: $0, style: settings.monthNames) ?? "" }
    }

    /// Whether the header column (0 is Sunday) is the weekly holiday's, so the
    /// header and the days under it are marked by the same rule.
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

    /// The cell's spoken label: the whole Bikram Sambat date, the weekday and
    /// the Gregorian date, so a cell read out of context still names its day,
    /// then its festivals by name, which is what the cell's mark stands for,
    /// and who the day is a public holiday for, which is what its red says.
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

    /// Last supported Bikram Sambat year, named in the range boundary state.
    var lastSupportedBSYear: Int { dataset.supportedRange.upperBound }
}
