// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Dibas Sigdel
import Foundation
import Observation
import NepalKitCore

/// Ticks every second so the popover's Nepal Time clock stays live and the
/// Bikram Sambat date flips at NPT midnight regardless of system time zone.
///
/// The NPT anchoring itself lives in NepalKitCore (`todayBS`/`todayAD`);
/// this model only owns `now` and formats it. `localTimeZone` is injected
/// for tests; production follows the system zone per read.
@MainActor
@Observable
final class ClockModel {
    private(set) var now: Date
    /// nil means "follow the system zone". Injected for tests. Resolved per read
    /// rather than stored: the app runs for weeks as a login item, and a zone
    /// captured at launch goes stale the moment the user travels.
    private let injectedLocalTimeZone: TimeZone?
    /// Test seam for a mid-session system-zone change. Production reads the live
    /// system zone; tests inject a mutable box. Global `NSTimeZone.default`
    /// mutation demonstrably does not move `TimeZone.current` on this platform,
    /// so travel cannot be simulated any other way.
    private let systemZone: () -> TimeZone

    private var timer: Timer?

    /// - Parameter refreshes: whether to schedule the timer that advances `now`
    ///   from the system clock. Production keeps the default. Pass `false` for
    ///   a still clock — a preview, or a test that only needs a fixed instant —
    ///   so no timer is left running.
    ///
    ///   The `Timer` returned by `scheduledTimer` is retained by the main run
    ///   loop, not by this model, and nothing here invalidates it: a weak
    ///   capture means the model can deallocate while the timer keeps firing
    ///   every second for the life of the process. A `#Preview` body is
    ///   re-evaluated whenever the canvas refreshes, and each evaluation would
    ///   schedule another one, so a preview built from the default leaked a
    ///   live timer per redraw.
    init(now: Date = .now, localTimeZone: TimeZone? = nil, systemZone: @escaping () -> TimeZone = { .autoupdatingCurrent }, refreshInterval: TimeInterval = 1, refreshes: Bool = true) {
        self.now = now
        self.injectedLocalTimeZone = localTimeZone
        self.systemZone = systemZone
        guard refreshes else { return }
        timer = scheduledMainActorTimer(withTimeInterval: refreshInterval, repeats: true) { [weak self] in
            self?.now = .now
        }
    }

    /// The zone the Local row shows. Reading the live system zone per read is
    /// what keeps a mid-session system zone change visible without a relaunch.
    var localTimeZone: TimeZone {
        injectedLocalTimeZone ?? systemZone()
    }

    /// Today's Bikram Sambat date for the current tick, or nil outside the dataset.
    func todayBSDate(in dataset: CalendarDataset = AppData.dataset) -> BSDay? {
        todayBS(now: now, in: dataset)
    }

    /// Today's Gregorian civil day in Nepal Time.
    func todayADDate() -> GADay? {
        todayAD(now: now)
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

    /// Whether showing Local alongside Nepal Time would repeat the same reading.
    ///
    /// Compared by UTC offset at this instant rather than by zone identity, because
    /// the question is whether the row adds information: someone in Kathmandu
    /// reading two identical clocks learns nothing from the second one, while
    /// someone in a different zone five and a half hours out always does.
    ///
    /// Offset-at-instant rather than `localTimeZone == nepalTimeZone` because zone
    /// identity is the wrong test. A zone with a different identifier can share
    /// Nepal's offset, and would then be showing a genuinely duplicated reading
    /// that identity comparison would miss.
    var localTimeIsRedundant: Bool {
        localTimeZone.secondsFromGMT(for: now) == nepalTimeZone.secondsFromGMT(for: now)
    }
}
