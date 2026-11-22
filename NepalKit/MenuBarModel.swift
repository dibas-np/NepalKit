// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Dibas Sigdel
import AppKit
import Foundation
import Observation
import NepalKitCore

/// Drives the menu-bar label's refresh with timers.
/// A `TimelineView` inside a `MenuBarExtra` label sends SwiftUI into a runaway
/// launch loop at 100% CPU, so the label reads state refreshed by timers instead:
/// a 30s backstop poll, a one-shot fire just after midnight in `timeZone`,
/// and a minute or second tick only while the title shows the time.
/// Wake and clock or time zone changes re-read the clock and reschedule.
@MainActor
@Observable
final class MenuBarModel {
    private(set) var now = Date.now
    /// Owned here, not with the display settings, because it changes timer scheduling.
    private(set) var format: MenuBarFormat
    private(set) var timeZone: TimeZone

    private var timer: Timer?
    private var midnightTimer: Timer?
    private var timeTickTimer: Timer?
    private let refreshes: Bool
    private let schedulesMidnightFire: Bool
    private let store: SettingsStore?
    private var clockObservers: [(center: NotificationCenter, token: any NSObjectProtocol)] = []

    /// Notification centers default in the body because a default argument is
    /// evaluated in a nonisolated context.
    /// - Parameter store: Where the menu-bar format is persisted. Nil keeps it in
    ///   memory at `.standard`, so tests never read the developer's own preferences.
    init(
        now: Date = .now,
        refreshInterval: TimeInterval = 30,
        refreshes: Bool = true,
        schedulesMidnightFire: Bool = true,
        store: SettingsStore? = nil,
        timeZone: TimeZone = .nepal,
        workspaceNotifications: NotificationCenter? = nil,
        systemNotifications: NotificationCenter? = nil
    ) {
        self.now = now
        self.format = store?.menuBarFormat ?? .standard
        self.timeZone = timeZone
        self.refreshes = refreshes
        self.schedulesMidnightFire = schedulesMidnightFire
        self.store = store
        if refreshes {
            timer = scheduledMainActorTimer(withTimeInterval: refreshInterval, repeats: true) { [weak self] in
                self?.pollForMissedChange()
            }
            observeClockDiscontinuity(
                NSWorkspace.didWakeNotification,
                on: workspaceNotifications ?? NSWorkspace.shared.notificationCenter
            )
            let system = systemNotifications ?? .default
            observeClockDiscontinuity(.NSSystemClockDidChange, on: system)
            observeClockDiscontinuity(.NSSystemTimeZoneDidChange, on: system)
        }
        if schedulesMidnightFire {
            scheduleMidnightFire()
        }
        scheduleTimeTick()
    }

    /// The run loop retains the timers and each center retains its block.
    isolated deinit {
        timer?.invalidate()
        midnightTimer?.invalidate()
        timeTickTimer?.invalidate()
        for observer in clockObservers {
            observer.center.removeObserver(observer.token)
        }
    }

    /// Writes only when the day has turned: the timers already cover every other
    /// change, and redrawing an unchanged item every 30s was most of the idle work.
    func pollForMissedChange() {
        let fresh = Date.now
        if GregorianDate.today(now: fresh, timeZone: timeZone) != GregorianDate.today(now: now, timeZone: timeZone) {
            now = fresh
        }
    }

    private func observeClockDiscontinuity(_ name: Notification.Name, on center: NotificationCenter) {
        let token = center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.refreshAfterClockDiscontinuity()
            }
        }
        clockObservers.append((center, token))
    }

    /// Reschedules both timers, whose intervals were measured before the jump.
    func refreshAfterClockDiscontinuity() {
        now = .now
        if schedulesMidnightFire {
            scheduleMidnightFire()
        }
        scheduleTimeTick()
    }

    /// `now` is re-read first because it can be a poll interval old.
    func save(_ format: MenuBarFormat) {
        store?.save(format)
        if refreshes {
            now = .now
        }
        self.format = format
        scheduleTimeTick()
    }

    /// Reschedules both timers, which were measured to the old zone.
    func setTimeZone(_ timeZone: TimeZone) {
        if refreshes {
            now = .now
        }
        self.timeZone = timeZone
        if schedulesMidnightFire {
            scheduleMidnightFire()
        }
        scheduleTimeTick()
    }

    var isTickingForTime: Bool {
        timeTickTimer != nil
    }

    /// Fires one second after midnight so the civil day has definitively rolled over.
    static nonisolated func midnightFireInterval(after date: Date, in timeZone: TimeZone = .nepal) -> TimeInterval? {
        guard let nextMidnight = timeZone.nextMidnight(after: date) else { return nil }
        return max(1, nextMidnight.timeIntervalSince(date) + 1)
    }

    /// Seconds to the next minute (or second) boundary in `timeZone`. No guard
    /// second: the tick reschedules from the clock it reads, so an early fire is
    /// followed at once by one past the boundary.
    static nonisolated func timeTickInterval(
        after date: Date,
        showsSeconds: Bool,
        in timeZone: TimeZone = .nepal
    ) -> TimeInterval {
        let period: TimeInterval = showsSeconds ? 1 : 60
        // Every zone in use is whole minutes from UTC, but the offset is applied anyway.
        let zoneSeconds = date.timeIntervalSinceReferenceDate + TimeInterval(timeZone.secondsFromGMT(for: date))
        let remainder = zoneSeconds.truncatingRemainder(dividingBy: period)
        let elapsed = remainder < 0 ? remainder + period : remainder
        return period - elapsed
    }

    private func scheduleTimeTick() {
        timeTickTimer?.invalidate()
        timeTickTimer = nil
        guard refreshes, format.showsTime else { return }
        let interval = Self.timeTickInterval(after: now, showsSeconds: format.showsSeconds, in: timeZone)
        timeTickTimer = scheduledMainActorTimer(withTimeInterval: interval, repeats: false) { [weak self] in
            self?.now = .now
            self?.scheduleTimeTick()
        }
    }

    private func scheduleMidnightFire() {
        midnightTimer?.invalidate()
        guard let interval = Self.midnightFireInterval(after: now, in: timeZone) else { return }
        midnightTimer = scheduledMainActorTimer(withTimeInterval: interval, repeats: false) { [weak self] in
            self?.now = .now
            self?.scheduleMidnightFire()
        }
    }
}
