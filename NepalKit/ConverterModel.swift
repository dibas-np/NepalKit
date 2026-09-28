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
/// bounded to the dataset's supported range (BS) and its convertible AD span.
@MainActor
@Observable
final class ConverterModel {
    var direction: ConverterDirection
    var bsYear: Int
    var bsMonth: Int
    var bsDay: Int
    var adYear: Int
    var adMonth: Int
    var adDay: Int

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
        self.bsYear = bsYear ?? todayBSDate?.year ?? dataset.supportedRange.lowerBound
        self.bsMonth = bsMonth ?? todayBSDate?.month ?? 1
        self.bsDay = bsDay ?? todayBSDate?.day ?? 1
        self.adYear = adYear ?? todayADDate?.year ?? 2026
        self.adMonth = adMonth ?? todayADDate?.month ?? 1
        self.adDay = adDay ?? todayADDate?.day ?? 1
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
        let current = GADay(year: adYear, month: adMonth, day: adDay)
        if compareAD(current, minAD) == .orderedAscending {
            adYear = minAD.year
            adMonth = minAD.month
            adDay = minAD.day
        } else if compareAD(current, maxAD) == .orderedDescending {
            adYear = maxAD.year
            adMonth = maxAD.month
            adDay = maxAD.day
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

    private func compareAD(_ lhs: GADay, _ rhs: GADay) -> ComparisonResult {
        if lhs.year != rhs.year { return lhs.year < rhs.year ? .orderedAscending : .orderedDescending }
        if lhs.month != rhs.month { return lhs.month < rhs.month ? .orderedAscending : .orderedDescending }
        if lhs.day != rhs.day { return lhs.day < rhs.day ? .orderedAscending : .orderedDescending }
        return .orderedSame
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
            if let ad = bsToAD(BSDay(year: bsYear, month: bsMonth, day: bsDay), in: dataset) {
                adYear = ad.year
                adMonth = ad.month
                adDay = ad.day
            }
            direction = .adToBS
        case .adToBS:
            if let bs = adToBS(GADay(year: adYear, month: adMonth, day: adDay), in: dataset) {
                bsYear = bs.year
                bsMonth = bs.month
                bsDay = bs.day
            }
            direction = .bsToAD
        }
    }

    /// Converted date plus weekday, honoring both display settings.
    func result(settings: DisplaySettings) -> String? {
        switch direction {
        case .bsToAD:
            let bs = BSDay(year: bsYear, month: bsMonth, day: bsDay)
            guard let ad = bsToAD(bs, in: dataset),
                  let day = weekday(of: bs, in: dataset),
                  let weekday = weekdayName(for: day, style: settings.monthNames)
            else { return nil }
            return "\(formatAD(ad, settings: settings)) · \(weekday)"
        case .adToBS:
            let ad = GADay(year: adYear, month: adMonth, day: adDay)
            guard let bs = adToBS(ad, in: dataset),
                  let day = weekday(of: bs, in: dataset),
                  let weekday = weekdayName(for: day, style: settings.monthNames)
            else { return nil }
            return "\(format(bs, settings: settings)) · \(weekday)"
        }
    }
}
