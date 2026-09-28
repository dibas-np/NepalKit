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
        set { bsDate = BSDay(year: newValue, month: bsDate.month, day: bsDate.day) }
    }

    var bsMonth: Int {
        get { bsDate.month }
        set { bsDate = BSDay(year: bsDate.year, month: newValue, day: bsDate.day) }
    }

    var bsDay: Int {
        get { bsDate.day }
        set { bsDate = BSDay(year: bsDate.year, month: bsDate.month, day: newValue) }
    }

    var adYear: Int {
        get { adDate.year }
        set { adDate = GADay(year: newValue, month: adDate.month, day: adDate.day) }
    }

    var adMonth: Int {
        get { adDate.month }
        set { adDate = GADay(year: adDate.year, month: newValue, day: adDate.day) }
    }

    var adDay: Int {
        get { adDate.day }
        set { adDate = GADay(year: adDate.year, month: adDate.month, day: newValue) }
    }

    private let dataset: CalendarDataset

    init(
        direction: ConverterDirection = .bsToAD,
        bsYear: Int? = nil, bsMonth: Int? = nil, bsDay: Int? = nil,
        adYear: Int? = nil, adMonth: Int? = nil, adDay: Int? = nil,
        dataset: CalendarDataset = .v1
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

    func clampBSDay() {
        let maxDay = daysInBSMonth(year: bsYear, month: bsMonth)
        bsDay = min(max(bsDay, 1), maxDay)
    }

    func clampADDay() {
        let maxDay = daysInADMonth(year: adYear, month: adMonth)
        adDay = min(max(adDay, 1), maxDay)
        clampADDate()
    }

    /// Keeps the AD pickers inside the convertible [minAD, maxAD] span.
    func clampADDate() {
        guard let minAD, let maxAD else { return }
        if adDate < minAD {
            adDate = minAD
        } else if adDate > maxAD {
            adDate = maxAD
        }
        // After clamping to the span, re-clamp month/day at the edges.
        if !adMonths(year: adYear).contains(adMonth) {
            adMonth = adMonths(year: adYear).first ?? adMonth
        }
        let maxDay = daysInADMonth(year: adYear, month: adMonth)
        adDay = min(max(adDay, 1), maxDay)
        if adYear == minAD.year, adMonth == minAD.month {
            adDay = max(adDay, minAD.day)
        }
        if adYear == maxAD.year, adMonth == maxAD.month {
            adDay = min(adDay, maxAD.day)
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
}
