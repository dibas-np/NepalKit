// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Dibas Sigdel
import Foundation
import Observation
import NepalKitCore

@MainActor
@Observable
final class ConverterModel {
    private(set) var direction: ConverterDirection

    private(set) var bsDate: BikramSambatDate
    private(set) var adDate: GregorianDate

    var bsYear: Int {
        get { bsDate.year }
        set {
            bsDate = BikramSambatDate(year: newValue, month: bsDate.month, day: bsDate.day)
            clampBSDay()
        }
    }

    var bsMonth: Int {
        get { bsDate.month }
        set {
            bsDate = BikramSambatDate(year: bsDate.year, month: newValue, day: bsDate.day)
            clampBSDay()
        }
    }

    var bsDay: Int {
        get { bsDate.day }
        set {
            bsDate = BikramSambatDate(year: bsDate.year, month: bsDate.month, day: newValue)
            clampBSDay()
        }
    }

    var adYear: Int {
        get { adDate.year }
        set {
            adDate = GregorianDate(year: newValue, month: adDate.month, day: adDate.day)
            clampADDate()
        }
    }

    var adMonth: Int {
        get { adDate.month }
        set {
            adDate = GregorianDate(year: adDate.year, month: newValue, day: adDate.day)
            clampADDate()
        }
    }

    var adDay: Int {
        get { adDate.day }
        set {
            adDate = GregorianDate(year: adDate.year, month: adDate.month, day: newValue)
            clampADDate()
        }
    }

    private let dataset: CalendarDataset

    init(
        direction: ConverterDirection = .bsToAD,
        bsYear: Int? = nil, bsMonth: Int? = nil, bsDay: Int? = nil,
        adYear: Int? = nil, adMonth: Int? = nil, adDay: Int? = nil,
        dataset: CalendarDataset = AppData.dataset,
        now: Date = .now,
        timeZone: TimeZone = .nepal
    ) {
        self.dataset = dataset
        self.direction = direction
        let todayADDate = GregorianDate.today(now: now, timeZone: timeZone) ?? dataset.anchorGregorian
        let defaultBSDate = Self.convertibleDay(nearest: todayADDate, in: dataset).flatMap { BikramSambatDate($0, in: dataset) }
        self.bsDate = BikramSambatDate(
            year: bsYear ?? defaultBSDate?.year ?? dataset.supportedRange.lowerBound,
            month: bsMonth ?? defaultBSDate?.month ?? 1,
            day: bsDay ?? defaultBSDate?.day ?? 1
        )
        self.adDate = GregorianDate(
            year: adYear ?? todayADDate.year,
            month: adMonth ?? todayADDate.month,
            day: adDay ?? todayADDate.day
        )
        clampBSDay()
        clampADDate()
    }

    private static func convertibleDay(nearest day: GregorianDate, in dataset: CalendarDataset) -> GregorianDate? {
        guard let first = dataset.gregorianStart, let last = dataset.gregorianEnd else { return nil }
        return min(max(day, first), last)
    }

    var bsYears: [Int] { Array(dataset.supportedRange) }

    var minAD: GregorianDate? { dataset.gregorianStart }

    var maxAD: GregorianDate? {
        dataset.gregorianEnd
    }

    var adYears: [Int] {
        guard let minAD, let maxAD else { return [] }
        return Array(minAD.year ... maxAD.year)
    }

    func adMonths(year: Int) -> [Int] {
        guard let minAD, let maxAD else { return Array(1 ... 12) }
        let lower = year == minAD.year ? minAD.month : 1
        let upper = year == maxAD.year ? maxAD.month : 12
        guard lower <= upper else { return [] }
        return Array(lower ... upper)
    }

    func daysInBSMonth(year: Int, month: Int) -> Int {
        precondition(dataset.supportedRange.contains(year), "BS year \(year) is outside the supported range")
        precondition((1 ... 12).contains(month), "BS month \(month) is outside 1...12")
        guard let months = dataset.monthLengths(for: year) else {
            preconditionFailure("Validated dataset is missing the month lengths for BS year \(year)")
        }
        return months[month - 1]
    }

    func daysInADMonth(year: Int, month: Int) -> Int {
        precondition((1 ... 12).contains(month), "AD month \(month) is outside 1...12")
        guard let days = GregorianDate.daysInMonth(year: year, month: month) else {
            preconditionFailure("Gregorian month \(month) has no day count for year \(year)")
        }
        return days
    }

    func adDays(year: Int, month: Int) -> [Int] {
        guard let minAD, let maxAD else { return Array(1 ... daysInADMonth(year: year, month: month)) }
        var lower = 1
        var upper = daysInADMonth(year: year, month: month)
        if year == minAD.year, month == minAD.month { lower = minAD.day }
        if year == maxAD.year, month == maxAD.month { upper = maxAD.day }
        guard lower <= upper else { return [] }
        return Array(lower ... upper)
    }

    private func clampBSDay() {
        let clampedYear = min(max(bsDate.year, dataset.supportedRange.lowerBound), dataset.supportedRange.upperBound)
        let clampedMonth = min(max(bsDate.month, 1), 12)
        let maxDay = daysInBSMonth(year: clampedYear, month: clampedMonth)
        let clampedDay = min(max(bsDate.day, 1), maxDay)
        let clamped = BikramSambatDate(year: clampedYear, month: clampedMonth, day: clampedDay)
        if clamped != bsDate {
            bsDate = clamped
        }
    }

    private func clampADDate() {
        guard let minAD, let maxAD else { return }
        var date = adDate
        let monthInYear = min(max(date.month, 1), 12)
        let maxDayInMonth = daysInADMonth(year: date.year, month: monthInYear)
        date = GregorianDate(year: date.year, month: monthInYear, day: min(max(date.day, 1), maxDayInMonth))
        if date < minAD {
            date = minAD
        } else if date > maxAD {
            date = maxAD
        }
        if date != adDate {
            adDate = date
        }
    }

    func setDirection(_ newDirection: ConverterDirection) {
        guard newDirection != direction else { return }
        toggleDirection()
    }

    func toggleDirection() {
        switch direction {
        case .bsToAD:
            if let ad = GregorianDate(bsDate, in: dataset) {
                adDate = ad
            }
        case .adToBS:
            if let bs = BikramSambatDate(adDate, in: dataset) {
                bsDate = bs
            }
        }
        direction = direction.swapped
    }

    var directionSelection: ConverterDirection {
        get { direction }
        set { setDirection(newValue) }
    }

    private func weekdayText(for bs: BikramSambatDate, style: MonthNameStyle) -> String? {
        guard let day = bs.weekday(in: dataset),
              let name = BikramSambatDate.weekdayName(day, style: style)
        else { return nil }
        return name
    }

    private func converted(settings: DisplaySettings) -> (shown: String, spoken: String)? {
        switch direction {
        case .bsToAD:
            guard let ad = GregorianDate(bsDate, in: dataset),
                  let weekday = weekdayText(for: bsDate, style: settings.monthNames)
            else { return nil }
            return (
                Strings.datedWithWeekday(ad.formatted(digits: settings.digits), weekday),
                "\(SpokenDate.gregorian(ad)), \(weekday)"
            )
        case .adToBS:
            guard let bs = BikramSambatDate(adDate, in: dataset),
                  let weekday = weekdayText(for: bs, style: settings.monthNames)
            else { return nil }
            return (
                Strings.datedWithWeekday(bs.formatted(settings), weekday),
                "\(SpokenDate.bikramSambat(bs, monthNames: settings.monthNames)), \(weekday)"
            )
        }
    }

    var resultIsProvisional: Bool {
        switch direction {
        case .bsToAD:
            dataset.isProvisional(bsDate.year)
        case .adToBS:
            BikramSambatDate(adDate, in: dataset).map { dataset.isProvisional($0.year) } ?? false
        }
    }

    func convertedText(settings: DisplaySettings) -> String? {
        converted(settings: settings)?.shown
    }

    func spokenResult(settings: DisplaySettings) -> String? {
        guard let spoken = converted(settings: settings)?.spoken else { return nil }
        return resultIsProvisional ? "\(spoken). \(Strings.converterProvisionalNote)" : spoken
    }
}
