// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Dibas Sigdel
import Foundation
import NepalKitCore

/// The Watch's read-only Today state: resolves the current Nepal Time day and
/// keeps it current without polling or persistence.
///
/// Lifecycle contract: `activate()` computes immediately, starts clock-change
/// observation and schedules a refresh for the next Nepal midnight;
/// `deactivate()` cancels both. Reactivating after any number of inactive days
/// recomputes at once. Repeated activation does not duplicate work — the
/// observation guard makes the second call a no-op. The clock is injected and
/// read exactly once per refresh; every refresh resolves from the current
/// reading and reschedules.
///
/// While active, a system clock change cancels the stale midnight work,
/// re-resolves and reschedules — forward and backward changes both land on
/// the correct day. A missed signal may leave the active display stale until
/// the next wake or activation, whose immediate recomputation is the
/// corrective fallback; no polling is added to mask it.
@MainActor
@Observable
final class TodayModel {
    /// The complete display meaning of the current day, or nil before the
    /// first resolution at launch.
    private(set) var display: WatchDayDisplay?

    private let now: @Sendable () -> Date
    private let dataset: CalendarDataset
    private let clockChanges: @Sendable () -> ClockChangeStream
    private let nextMidnight: @Sendable (Date) -> Date?
    /// The production resolver by default; the development fixture harness
    /// injects failure points through it without changing any calendar answer.
    private let resolveDay: @Sendable (GADay, CalendarDataset) throws -> ResolvedDay

    private var midnightTask: Task<Void, Never>?
    private var clockChangeTask: Task<Void, Never>?

    init(
        now: @escaping @Sendable () -> Date = { Date.now },
        dataset: CalendarDataset = .v2,
        clockChanges: @escaping @Sendable () -> ClockChangeStream = { NotificationCenter.default.systemClockChangeStream() },
        nextMidnight: @escaping @Sendable (Date) -> Date? = { nextNPTMidnight(after: $0) },
        resolveDay: @escaping @Sendable (GADay, CalendarDataset) throws -> ResolvedDay = resolvedDay(for:in:)
    ) {
        self.now = now
        self.dataset = dataset
        self.clockChanges = clockChanges
        self.nextMidnight = nextMidnight
        self.resolveDay = resolveDay
    }

    /// Launch or foreground activation. Repeated activation while already
    /// active does nothing — the observation task is the marker of an active
    /// lifecycle, so recomputation, scheduling and subscription cannot
    /// duplicate.
    func activate() {
        guard clockChangeTask == nil else { return }
        refresh()
        observeClockChanges()
    }

    /// Background or inactivation: cancel the scheduled midnight refresh and
    /// the clock-change observation; the next activation recomputes.
    func deactivate() {
        midnightTask?.cancel()
        midnightTask = nil
        clockChangeTask?.cancel()
        clockChangeTask = nil
    }

    /// Reads the clock once, resolves the current Nepal Time day, and
    /// reschedules the next-midnight refresh.
    private func refresh() {
        let instant = now()
        do {
            guard let today = try todayAD(now: instant) else {
                throw DayResolutionError.unreadableInstant(instant)
            }
            let day = try resolveDay(today, dataset)
            display = watchDayDisplay(for: day, settings: .watch, in: dataset)
        } catch let error as DayResolutionError {
            display = watchCalculationErrorDisplay(
                gregorianDay: error.resolvedGregorianDay,
                settings: .watch
            )
        } catch {
            display = watchCalculationErrorDisplay(gregorianDay: nil, settings: .watch)
        }
        scheduleMidnightRefresh(after: instant)
    }

    /// Sleeps until the next Nepal midnight, then re-resolves from the clock
    /// as it stands at wake — never from the instant the schedule was made.
    private func scheduleMidnightRefresh(after instant: Date) {
        midnightTask?.cancel()
        guard let next = nextMidnight(instant) else {
            // Calendar arithmetic failed to name the next midnight: the
            // display stays as resolved until the next wake, activation or
            // clock-change signal recomputes. No polling is added to mask it.
            return
        }
        let interval = next.timeIntervalSince(instant)
        midnightTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(interval))
            guard !Task.isCancelled else { return }
            self?.refresh()
        }
    }

    /// Owns one clock-change observation for the active lifecycle. Cancelling
    /// the task ends the stream, which removes the notification observer.
    private func observeClockChanges() {
        guard clockChangeTask == nil else { return }
        let stream = clockChanges()
        clockChangeTask = Task { [weak self] in
            for await _ in stream {
                self?.refresh()
            }
        }
    }
}
