// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Dibas Sigdel
import Foundation
import NepalKitCore
import NepalKitWatchSupport

/// The Watch's Today state: resolves the current Nepal Time day and keeps it
/// current without polling.
///
/// While active, it refreshes at each Nepal midnight and on system clock
/// changes; every activation recomputes immediately.
@MainActor
@Observable
final class TodayModel {
    /// The current day's display, or nil before the first resolution.
    private(set) var display: WatchDayDisplay?

    private let now: @Sendable () -> Date
    private let dataset: CalendarDataset
    private let clockChanges: @Sendable () -> ClockChangeStream
    private let nextMidnight: @Sendable (Date) -> Date?
    /// Injectable so fixtures can force resolution failures.
    private let displayFor: @Sendable (Date) -> WatchDayDisplay

    private var midnightTask: Task<Void, Never>?
    private var clockChangeTask: Task<Void, Never>?

    init(
        now: @escaping @Sendable () -> Date = { Date.now },
        dataset: CalendarDataset = .v2,
        clockChanges: @escaping @Sendable () -> ClockChangeStream = { NotificationCenter.default.systemClockChangeStream() },
        nextMidnight: @escaping @Sendable (Date) -> Date? = { TimeZone.nepal.nextMidnight(after: $0) },
        displayFor: @escaping @Sendable (Date) -> WatchDayDisplay
    ) {
        self.now = now
        self.dataset = dataset
        self.clockChanges = clockChanges
        self.nextMidnight = nextMidnight
        self.displayFor = displayFor
    }

    convenience init(
        now: @escaping @Sendable () -> Date = { Date.now },
        dataset: CalendarDataset = .v2,
        clockChanges: @escaping @Sendable () -> ClockChangeStream = { NotificationCenter.default.systemClockChangeStream() },
        nextMidnight: @escaping @Sendable (Date) -> Date? = { TimeZone.nepal.nextMidnight(after: $0) }
    ) {
        self.init(now: now, dataset: dataset, clockChanges: clockChanges, nextMidnight: nextMidnight) { instant in
            watchDayDisplay(now: instant, settings: .watch, in: dataset)
        }
    }

    /// The display for an arbitrary instant. Always On renders through this,
    /// since a dimmed scene may never see the midnight refresh.
    func display(at instant: Date) -> WatchDayDisplay {
        displayFor(instant)
    }

    /// Idempotent while already active.
    func activate() {
        guard clockChangeTask == nil else { return }
        refresh()
        observeClockChanges()
    }

    func deactivate() {
        midnightTask?.cancel()
        midnightTask = nil
        clockChangeTask?.cancel()
        clockChangeTask = nil
    }

    private func refresh() {
        let instant = now()
        display = displayFor(instant)
        scheduleMidnightRefresh(after: instant)
    }

    /// Re-reads the clock at wake rather than trusting the scheduled instant.
    private func scheduleMidnightRefresh(after instant: Date) {
        midnightTask?.cancel()
        guard let next = nextMidnight(instant) else {
            // The display stays as is until the next activation or clock change.
            return
        }
        let interval = next.timeIntervalSince(instant)
        midnightTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(interval))
            guard !Task.isCancelled else { return }
            self?.refresh()
        }
    }

    /// Cancelling the task ends the stream, which removes the observer.
    private func observeClockChanges() {
        guard clockChangeTask == nil else { return }
        let stream = clockChanges()
        clockChangeTask = Task { [weak self] in
            for await _ in stream {
                // AsyncStream may deliver buffered events after cancellation.
                guard !Task.isCancelled else { return }
                self?.refresh()
            }
        }
    }
}
