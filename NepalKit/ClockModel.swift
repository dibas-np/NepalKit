// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Dibas Sigdel
import Foundation
import Observation
import NepalKitCore

/// Ticks while the popover is visible so its clocks stay live and the date
/// flips at midnight in the chosen time reference (ADR-0017).
@MainActor
@Observable
final class ClockModel {
    private(set) var now: Date
    /// Assigned only on a change, so day-level views are not invalidated every tick.
    private(set) var today: GregorianDate?
    /// False when both clocks read the same; assigned only on a change, like `today`.
    private(set) var showsSecondaryClock = false
    private(set) var timeReference: TimeReference
    /// nil follows the system zone, resolved per read so travel shows without a relaunch.
    private let injectedLocalTimeZone: TimeZone?
    /// Injected so tests can change the system zone mid-session: mutating
    /// `NSTimeZone.default` does not move `TimeZone.current` on this platform.
    private let systemZone: () -> TimeZone

    private let currentTime: () -> Date
    private let refreshInterval: Duration
    private let refreshes: Bool
    private let sleep: @MainActor (Duration) async throws -> Void

    /// Schedules no work; the popover owns the refresh task.
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
        self.today = GregorianDate.today(now: now, timeZone: timeZone)
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

    var localTimeZone: TimeZone {
        injectedLocalTimeZone ?? systemZone()
    }

    /// Nothing to schedule: the popover's tick re-reads both clocks every second.
    func setTimeReference(_ timeReference: TimeReference) {
        self.timeReference = timeReference
        refreshToday()
    }

    private func refreshToday() {
        let day = GregorianDate.today(now: now, timeZone: timeZone)
        if day != today { today = day }
        let differs = !localTimeIsRedundant
        if differs != showsSecondaryClock { showsSecondaryClock = differs }
    }

    /// Uses `localTimeZone` so a test's injected zone governs both the day and the clocks.
    var timeZone: TimeZone {
        switch timeReference {
        case .nepal: TimeZone.nepal
        case .local: localTimeZone
        }
    }

    func todayBSDate(in dataset: CalendarDataset = AppData.dataset) -> BikramSambatDate? {
        today.flatMap { BikramSambatDate($0, in: dataset) }
    }

    func todayADDate() -> GregorianDate? {
        today
    }

    /// Derived from the Gregorian day, so it survives past the supported range.
    func weekdayString(style: MonthNameStyle) -> String? {
        guard let day = todayADDate(), let weekday = day.weekday else { return nil }
        return BikramSambatDate.weekdayName(weekday, style: style)
    }

    func nptTimeString(digits: DigitScript) -> String {
        digits.formatTime(now, in: .nepal)
    }

    func localTimeString(digits: DigitScript) -> String {
        digits.formatTime(now, in: localTimeZone)
    }

    /// Compared by UTC offset at this instant, not zone identity: another zone can
    /// share Nepal's offset.
    var localTimeIsRedundant: Bool {
        localTimeZone.secondsFromGMT(for: now) == TimeZone.nepal.secondsFromGMT(for: now)
    }

    // MARK: - The two clocks

    /// The clock today follows, since the date beneath it was read from that clock.
    var headerClockLabel: String {
        switch timeReference {
        case .nepal: Strings.nepalTimeLabel
        case .local: Strings.localTimeLabel
        }
    }

    func headerTimeString(digits: DigitScript) -> String {
        digits.formatTime(now, in: timeZone)
    }

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
