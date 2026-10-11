// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Dibas Sigdel
import Foundation
import Observation
import NepalKitCore

/// Ticks while the popover is visible so its clocks stay live and the Bikram
/// Sambat date flips at midnight in the zone the user chose: Nepal Time by
/// default, whatever the system zone, or the Mac's own zone (ADR-0017).
///
/// The anchoring itself lives in NepalKitCore (`todayBS`/`todayAD`); this
/// model only owns `now`, the time reference, and formats them. `localTimeZone`
/// is injected for tests; production follows the system zone per read.
@MainActor
@Observable
final class ClockModel {
    private(set) var now: Date
    /// Today's Gregorian day in `timeZone`, stored apart from `now` and assigned
    /// only when it changes, so views that show the day (the Today hero) are
    /// invalidated once a day rather than on every per-second tick.
    private(set) var today: GADay?
    /// Whether the secondary clock row shows: the two clocks read differently.
    /// The comparison is symmetric, so the row hides on the same condition
    /// whichever clock is the header's: two identical readings, which is every
    /// Mac set to Nepal's offset. Stored, like `today`, and assigned only on a
    /// change (a zone switch or a daylight-saving change), so the row is not
    /// invalidated every tick.
    private(set) var showsSecondaryClock = false
    /// Which clock today follows, and so which one the header shows.
    private(set) var timeReference: TimeReference
    /// nil means "follow the system zone". Injected for tests. Resolved per read
    /// rather than stored: the app runs for weeks as a login item, and a zone
    /// captured at launch goes stale the moment the user travels.
    private let injectedLocalTimeZone: TimeZone?
    /// Test seam for a mid-session system-zone change. Production reads the live
    /// system zone; tests inject a mutable box. Global `NSTimeZone.default`
    /// mutation demonstrably does not move `TimeZone.current` on this platform,
    /// so travel cannot be simulated any other way.
    private let systemZone: () -> TimeZone

    private let currentTime: () -> Date
    private let refreshInterval: Duration
    private let refreshes: Bool
    private let sleep: @MainActor (Duration) async throws -> Void

    /// Initialization schedules no work. The popover owns the refresh task.
    /// Set `refreshes` to false for fixed previews and date-formatting tests.
    init(
        now: Date = .now,
        localTimeZone: TimeZone? = nil,
        timeReference: TimeReference = .nepal,
        systemZone: @escaping () -> TimeZone = { .autoupdatingCurrent },
        refreshInterval: TimeInterval = 1,
        refreshes: Bool = true,
        currentTime: @escaping () -> Date = { .now },
        sleep: @escaping @MainActor (Duration) async throws -> Void = { try await Task.sleep(for: $0) }
    ) {
        self.now = now
        self.injectedLocalTimeZone = localTimeZone
        self.timeReference = timeReference
        self.systemZone = systemZone
        self.refreshInterval = .seconds(refreshInterval)
        self.refreshes = refreshes
        self.currentTime = currentTime
        self.sleep = sleep
        self.today = todayAD(now: now, timeZone: timeZone)
        self.showsSecondaryClock = !localTimeIsRedundant
    }

    /// Refreshes immediately, then once per interval until the view cancels its task.
    func refreshWhileVisible() async {
        guard refreshes else { return }
        while !Task.isCancelled {
            now = currentTime()
            refreshToday()
            do {
                try await sleep(refreshInterval)
            } catch {
                return
            }
        }
    }

    /// The zone the Local row shows. Reading the live system zone per read is
    /// what keeps a mid-session system zone change visible without a relaunch.
    var localTimeZone: TimeZone {
        injectedLocalTimeZone ?? systemZone()
    }

    /// Follows a new time reference. Today is re-read at once and the clocks
    /// read the new zone on their next read; nothing is scheduled here, because
    /// the popover's tick re-reads both every second.
    func setTimeReference(_ timeReference: TimeReference) {
        self.timeReference = timeReference
        refreshToday()
    }

    /// Re-reads today from `now`, assigning only on a change so an unchanged
    /// day notifies no one.
    private func refreshToday() {
        let day = todayAD(now: now, timeZone: timeZone)
        if day != today { today = day }
        let differs = !localTimeIsRedundant
        if differs != showsSecondaryClock { showsSecondaryClock = differs }
    }

    /// The zone today is read in: Nepal Time, or `localTimeZone`. Local is the
    /// model's own `localTimeZone` rather than `TimeReference.timeZone`, so a
    /// test's injected zone governs both the day and the clocks.
    var timeZone: TimeZone {
        switch timeReference {
        case .nepal: nepalTimeZone
        case .local: localTimeZone
        }
    }

    /// Today's Bikram Sambat date for the current tick, or nil outside the dataset.
    func todayBSDate(in dataset: CalendarDataset = AppData.dataset) -> BSDay? {
        today.flatMap { adToBS($0, in: dataset) }
    }

    /// Today's Gregorian civil day in the zone today follows.
    func todayADDate() -> GADay? {
        today
    }

    /// Weekday of today's civil day, in the selected display language.
    ///
    /// Derived from today's Gregorian day rather than from a Bikram
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

    // MARK: - The two clocks

    /// The header's clock: the one today follows. Nepal Time by default; the
    /// Mac's own time when the user chose it, because then that is the clock
    /// the date beneath it was read from.
    var headerClockLabel: String {
        switch timeReference {
        case .nepal: Strings.nepalTimeLabel
        case .local: Strings.localTimeLabel
        }
    }

    func headerTimeString(digits: DigitScript) -> String {
        formatClock(now, timeZone: timeZone, digits: digits)
    }

    /// The secondary row's clock: whichever of the two the header does not show.
    var secondaryClockLabel: String {
        switch timeReference {
        case .nepal: Strings.localTimeLabel
        case .local: Strings.nepalTimeLabel
        }
    }

    func secondaryTimeString(digits: DigitScript) -> String {
        switch timeReference {
        case .nepal: localTimeString(digits: digits)
        case .local: nptTimeString(digits: digits)
        }
    }

}
