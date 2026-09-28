import Foundation
import Observation
import NepalKitCore

/// Ticks every second so the popover's Nepal Time clock stays live and the
/// Bikram Sambat date flips at NPT midnight regardless of system time zone.
///
/// The NPT anchoring itself lives in NepalKitCore (`todayBS`/`todayAD`);
/// this model only owns `now` and formats it. `localTimeZone` is injected
/// so the NPT-vs-local comparison is testable.
@MainActor
@Observable
final class ClockModel {
    private(set) var now: Date
    let localTimeZone: TimeZone

    private var timer: Timer?

    init(now: Date = Date(), localTimeZone: TimeZone = .current, refreshInterval: TimeInterval = 1) {
        self.now = now
        self.localTimeZone = localTimeZone
        timer = Timer.scheduledTimer(withTimeInterval: refreshInterval, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.now = Date() }
        }
    }

    /// Today's Bikram Sambat date for the current tick, or nil outside the dataset.
    func todayBSDate(in dataset: CalendarDataset = .v2) -> BSDay? {
        todayBS(now: now, in: dataset)
    }

    /// Today's Gregorian civil day in Nepal Time.
    func todayADDate() -> GADay? {
        todayAD(now: now)
    }

    func bsString(settings: DisplaySettings, in dataset: CalendarDataset = .v2) -> String? {
        guard let bs = todayBSDate(in: dataset) else { return nil }
        return formatBS(bs, settings: settings)
    }

    func gregorianString(settings: DisplaySettings) -> String? {
        guard let ad = todayADDate() else { return nil }
        return formatAD(ad, settings: settings)
    }

    /// Weekday of today's civil day, in the selected display language.
    ///
    /// Derived from the Nepal Time Gregorian day rather than from a Bikram
    /// Sambat conversion: the weekday is a property of the date, so it stays
    /// available past the dataset's supported range, where the Bikram Sambat
    /// date does not.
    func weekdayString(style: MonthNameStyle) -> String? {
        guard let day = todayADDate(), let weekday = weekday(of: day) else { return nil }
        return weekdayName(for: weekday, style: style)
    }

    func nptTimeString(digits: DigitScript) -> String {
        formatClock(now, timeZone: nepalTimeZone, digits: digits)
    }

    func localTimeString(digits: DigitScript) -> String {
        formatClock(now, timeZone: localTimeZone, digits: digits)
    }
}
