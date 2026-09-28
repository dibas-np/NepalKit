// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Dibas Sigdel
import Foundation
import Observation
import NepalKitCore

/// Direction of conversion. The toggle preserves the converted date so the
/// user never re-enters anything.
enum ConverterDirection: Hashable {
    case bsToAD
    case adToBS
}

/// Owns the converter's picker state. Day pickers are clamped to the real
/// month length, so invalid dates are structurally impossible; years are
/// bounded to the dataset's supported range (Bikram Sambat) and its
/// convertible Gregorian span.
@MainActor
@Observable
final class ConverterModel {
    var direction: ConverterDirection

    /// Picker state bundled as dates: one value travels together instead of
    /// six ints. The `*Year/*Month/*Day` accessors below exist for the
    /// pickers, tests, and bindings.
    var bsDate: BSDay
    var adDate: GADay

    var bsYear: Int {
        get { bsDate.year }
        set {
            bsDate = BSDay(year: newValue, month: bsDate.month, day: bsDate.day)
            clampBSDay()
        }
    }

    var bsMonth: Int {
        get { bsDate.month }
        set {
            bsDate = BSDay(year: bsDate.year, month: newValue, day: bsDate.day)
            clampBSDay()
        }
    }

    var bsDay: Int {
        get { bsDate.day }
        set {
            bsDate = BSDay(year: bsDate.year, month: bsDate.month, day: newValue)
            clampBSDay()
        }
    }

    var adYear: Int {
        get { adDate.year }
        set {
            adDate = GADay(year: newValue, month: adDate.month, day: adDate.day)
            clampADDate()
        }
    }

    var adMonth: Int {
        get { adDate.month }
        set {
            adDate = GADay(year: adDate.year, month: newValue, day: adDate.day)
            clampADDate()
        }
    }

    var adDay: Int {
        get { adDate.day }
        set {
            adDate = GADay(year: adDate.year, month: adDate.month, day: newValue)
            clampADDate()
        }
    }

    private let dataset: CalendarDataset

    init(
        direction: ConverterDirection = .bsToAD,
        bsYear: Int? = nil, bsMonth: Int? = nil, bsDay: Int? = nil,
        adYear: Int? = nil, adMonth: Int? = nil, adDay: Int? = nil,
        dataset: CalendarDataset = .v2
    ) {
        self.dataset = dataset
        self.direction = direction
        let todayBSDate = todayBS(now: Date(), in: dataset)
        let todayADDate = todayAD(now: Date())
        self.bsDate = BSDay(
            year: bsYear ?? todayBSDate?.year ?? dataset.supportedRange.lowerBound,
            month: bsMonth ?? todayBSDate?.month ?? 1,
            day: bsDay ?? todayBSDate?.day ?? 1
        )
        self.adDate = GADay(
            year: adYear ?? todayADDate?.year ?? 2026,
            month: adMonth ?? todayADDate?.month ?? 1,
            day: adDay ?? todayADDate?.day ?? 1
        )
        clampBSDay()
        clampADDay()
    }

    var bsYears: [Int] { Array(dataset.supportedRange) }

    var minAD: GADay? {
        bsToAD(BSDay(year: dataset.supportedRange.lowerBound, month: 1, day: 1), in: dataset)
    }

    var maxAD: GADay? {
        guard let maxBSMonths = dataset.monthLengths(for: dataset.supportedRange.upperBound) else { return nil }
        return bsToAD(
            BSDay(year: dataset.supportedRange.upperBound, month: 12, day: maxBSMonths[11]),
            in: dataset
        )
    }

    var adYears: [Int] {
        guard let minAD, let maxAD else { return [] }
        return Array(minAD.year ... maxAD.year)
    }

    /// Gregorian months available in the given AD year, bounded by the
    /// convertible span at the edges.
    func adMonths(year: Int) -> [Int] {
        guard let minAD, let maxAD else { return Array(1 ... 12) }
        let lower = year == minAD.year ? minAD.month : 1
        let upper = year == maxAD.year ? maxAD.month : 12
        guard lower <= upper else { return [] }
        return Array(lower ... upper)
    }

    func daysInBSMonth(year: Int, month: Int) -> Int {
        dataset.monthLengths(for: year)?[month - 1] ?? 30
    }

    func daysInADMonth(year: Int, month: Int) -> Int {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        var components = DateComponents()
        components.year = year
        components.month = month
        guard let date = calendar.date(from: components),
              let range = calendar.range(of: .day, in: .month, for: date)
        else { return 30 }
        return range.count
    }

    /// Gregorian days available for the given month, bounded by the
    /// convertible span at the edges so invalid dates can't be picked.
    func adDays(year: Int, month: Int) -> [Int] {
        guard let minAD, let maxAD else { return Array(1 ... daysInADMonth(year: year, month: month)) }
        var lower = 1
        var upper = daysInADMonth(year: year, month: month)
        if year == minAD.year, month == minAD.month { lower = minAD.day }
        if year == maxAD.year, month == maxAD.month { upper = maxAD.day }
        guard lower <= upper else { return [] }
        return Array(lower ... upper)
    }

    /// Clamps the BS pickers into the dataset's supported range and the real
    /// month length. Writes `bsDate` directly (never through the setters) so
    /// the setters can call this safely without recursing. Idempotent, so
    /// existing call sites that call it explicitly keep working.
    func clampBSDay() {
        let clampedYear = min(max(bsDate.year, dataset.supportedRange.lowerBound), dataset.supportedRange.upperBound)
        let clampedMonth = min(max(bsDate.month, 1), 12)
        let maxDay = daysInBSMonth(year: clampedYear, month: clampedMonth)
        let clampedDay = min(max(bsDate.day, 1), maxDay)
        let clamped = BSDay(year: clampedYear, month: clampedMonth, day: clampedDay)
        if clamped != bsDate {
            bsDate = clamped
        }
    }

    func clampADDay() {
        clampADDate()
    }

    /// Keeps the AD pickers inside the convertible [minAD, maxAD] span.
    /// Writes `adDate` once at the end (never through the setters) so the
    /// setters can call this safely without recursing. Idempotent.
    func clampADDate() {
        guard let minAD, let maxAD else { return }
        var date = adDate
        // Real calendar bounds first.
        let monthInYear = min(max(date.month, 1), 12)
        let maxDayInMonth = daysInADMonth(year: date.year, month: monthInYear)
        date = GADay(year: date.year, month: monthInYear, day: min(max(date.day, 1), maxDayInMonth))
        // Convertible span.
        if date < minAD {
            date = minAD
        } else if date > maxAD {
            date = maxAD
        }
        // After clamping to the span, re-clamp month/day at the edges.
        if !adMonths(year: date.year).contains(date.month) {
            let fallback = adMonths(year: date.year).first ?? date.month
            let maxDay = daysInADMonth(year: date.year, month: fallback)
            date = GADay(year: date.year, month: fallback, day: min(max(date.day, 1), maxDay))
        }
        var day = min(max(date.day, 1), daysInADMonth(year: date.year, month: date.month))
        if date.year == minAD.year, date.month == minAD.month {
            day = max(day, minAD.day)
        }
        if date.year == maxAD.year, date.month == maxAD.month {
            day = min(day, maxAD.day)
        }
        let clamped = GADay(year: date.year, month: date.month, day: day)
        if clamped != adDate {
            adDate = clamped
        }
    }

    /// Sets the direction, carrying the converted date across. No-op when
    /// the direction is unchanged, so re-tapping the active segment is safe.
    func setDirection(_ newDirection: ConverterDirection) {
        guard newDirection != direction else { return }
        toggleDirection()
    }

    /// Switches direction, carrying the converted date across so nothing is re-entered.
    func toggleDirection() {
        switch direction {
        case .bsToAD:
            if let ad = bsToAD(bsDate, in: dataset) {
                adDate = ad
            }
            direction = .adToBS
        case .adToBS:
            if let bs = adToBS(adDate, in: dataset) {
                bsDate = bs
            }
            direction = .bsToAD
        }
    }

    /// Weekday name for the given Bikram Sambat date, or nil outside the table.
    private func weekdayText(for bs: BSDay, style: MonthNameStyle) -> String? {
        guard let day = weekday(of: bs, in: dataset),
              let name = weekdayName(for: day, style: style)
        else { return nil }
        return name
    }

    /// Converted date plus weekday, honoring both display settings.
    /// Gregorian months stay English (no Nepali Gregorian names are defined);
    /// digits and weekday names honor the settings.
    /// Returns nil only defensively: bounded pickers keep every selectable
    /// date inside the convertible span.
    func convertedText(settings: DisplaySettings) -> String? {
        switch direction {
        case .bsToAD:
            guard let ad = bsToAD(bsDate, in: dataset),
                  let weekday = weekdayText(for: bsDate, style: settings.monthNames)
            else { return nil }
            return "\(formatAD(ad, settings: settings)) · \(weekday)"
        case .adToBS:
            guard let bs = adToBS(adDate, in: dataset),
                  let weekday = weekdayText(for: bs, style: settings.monthNames)
            else { return nil }
            return "\(formatBS(bs, settings: settings)) · \(weekday)"
        }
    }

    /// The converted date as it should be spoken, in whichever calendar the
    /// conversion produced.
    ///
    /// Parallel to `convertedText` and derived from the same conversion, so the
    /// spoken value cannot describe a different day than the shown one. The
    /// month-name language still follows the user's setting, because a matching
    /// VoiceOver voice reads it; only the digits are made pronounceable.
    func spokenResult(monthNames: MonthNameStyle) -> String? {
        switch direction {
        case .bsToAD:
            guard let ad = bsToAD(bsDate, in: dataset),
                  let weekday = weekdayText(for: bsDate, style: monthNames)
            else { return nil }
            return "\(SpokenDate.ad(ad)), \(weekday)"
        case .adToBS:
            guard let bs = adToBS(adDate, in: dataset),
                  let weekday = weekdayText(for: bs, style: monthNames)
            else { return nil }
            return "\(SpokenDate.bs(bs, monthNames: monthNames)), \(weekday)"
        }
    }
}
