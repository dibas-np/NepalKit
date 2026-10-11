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
}

/// One filled cell of the month grid: a Bikram Sambat day, the Gregorian day it
/// falls on, and its weekday, which belongs to the civil day and not to either
/// calendar (CONTEXT.md, *Weekday*).
struct MonthGridDay: Hashable {
    let bikramSambat: BSDay
    let gregorian: GADay
    /// 1 (Sunday) through 7 (Saturday), as the core reports it.
    let weekday: Int
    let isToday: Bool
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

    /// True when today's Nepal Time date is later than the last day the dataset
    /// covers. The range boundary state: today's month cannot be shown, so the
    /// grid opens on the last supported month and the view says why.
    private(set) var isTodayPastSupportedRange: Bool

    private let dataset: CalendarDataset

    /// - Parameter now: the instant today is read from. Injected so a test or a
    ///   preview does not depend on the day it runs.
    init(dataset: CalendarDataset = AppData.dataset, now: Date = .now) {
        self.dataset = dataset
        let state = Self.todayState(now: now, in: dataset)
        self.today = state.today
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
        shown = shown.month == 1
            ? MonthGridMonth(year: shown.year - 1, month: 12)
            : MonthGridMonth(year: shown.year, month: shown.month - 1)
    }

    func showNextMonth() {
        guard canShowNextMonth else { return }
        shown = shown.month == 12
            ? MonthGridMonth(year: shown.year + 1, month: 1)
            : MonthGridMonth(year: shown.year, month: shown.month + 1)
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
        if isTodayPastSupportedRange != state.isPastRange { isTodayPastSupportedRange = state.isPastRange }
    }

    private static func todayState(now: Date, in dataset: CalendarDataset) -> (today: BSDay?, isPastRange: Bool) {
        let today = todayBS(now: now, in: dataset)
        var isPastRange = false
        if today == nil, let todayAD = todayAD(now: now), let end = dataset.gregorianEnd {
            isPastRange = todayAD > end
        }
        return (today, isPastRange)
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

    /// The shown month as Sunday-first weeks of seven cells. A nil cell is a
    /// blank before day 1 or after the last day. Nepali wall calendars start the
    /// week on Sunday (आइतबार), which is also the core's weekday 1.
    var weeks: [[MonthGridDay?]] {
        guard let lengths = dataset.monthLengths(for: shown.year) else {
            preconditionFailure("Validated dataset is missing the month lengths for BS year \(shown.year)")
        }
        let length = lengths[shown.month - 1]
        var cells: [MonthGridDay?] = []
        for day in 1 ... length {
            let bs = BSDay(year: shown.year, month: shown.month, day: day)
            // Every day of a supported month converts; the dataset's own init
            // validates the table this walks.
            guard let ad = bsToAD(bs, in: dataset), let weekday = weekday(of: ad) else {
                preconditionFailure("Supported BS day \(bs) did not convert")
            }
            if day == 1 {
                cells.append(contentsOf: Array(repeating: nil, count: weekday - 1))
            }
            cells.append(MonthGridDay(bikramSambat: bs, gregorian: ad, weekday: weekday, isToday: bs == today))
        }
        let trailing = (7 - cells.count % 7) % 7
        cells.append(contentsOf: Array(repeating: nil, count: trailing))
        return stride(from: 0, to: cells.count, by: 7).map { Array(cells[$0 ..< $0 + 7]) }
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

    static func shortWeekdayName(_ weekday: Int, style: MonthNameStyle) -> String {
        guard let name = weekdayName(for: weekday, style: style) else { return "" }
        switch style {
        case .nepali: return name
        case .transliterated: return String(name.prefix(3))
        }
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
    /// the Gregorian date, so a cell read out of context still names its day.
    func spokenLabel(for day: MonthGridDay, settings: DisplaySettings) -> String {
        let parts = [
            day.isToday ? Strings.todayLabel : nil,
            SpokenDate.bs(day.bikramSambat, monthNames: settings.monthNames),
            weekdayName(for: day.weekday, style: settings.monthNames),
            SpokenDate.ad(day.gregorian),
        ]
        return parts.compactMap { $0 }.joined(separator: ", ")
    }

    /// Last supported Bikram Sambat year, named in the range boundary state.
    var lastSupportedBSYear: Int { dataset.supportedRange.upperBound }
}
