// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Dibas Sigdel
import AppKit
import Foundation
import Observation
import NepalKitCore

@MainActor
@Observable
final class MenuBarModel {
    private(set) var now = Date.now
    private(set) var format: MenuBarFormat
    private(set) var timeZone: TimeZone

    private var timer: Timer?
    private var midnightTimer: Timer?
    private var timeTickTimer: Timer?
    private let refreshes: Bool
    private let schedulesMidnightFire: Bool
    private let store: SettingsStore?
    private var clockObservers: [(center: NotificationCenter, token: any NSObjectProtocol)] = []

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

    isolated deinit {
        timer?.invalidate()
        midnightTimer?.invalidate()
        timeTickTimer?.invalidate()
        for observer in clockObservers {
            observer.center.removeObserver(observer.token)
        }
    }

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

    func refreshAfterClockDiscontinuity() {
        now = .now
        if schedulesMidnightFire {
            scheduleMidnightFire()
        }
        scheduleTimeTick()
    }

    func save(_ format: MenuBarFormat) {
        store?.save(format)
        if refreshes {
            now = .now
        }
        self.format = format
        scheduleTimeTick()
    }

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

    static nonisolated func midnightFireInterval(after date: Date, in timeZone: TimeZone = .nepal) -> TimeInterval? {
        guard let nextMidnight = timeZone.nextMidnight(after: date) else { return nil }
        return max(1, nextMidnight.timeIntervalSince(date) + 1)
    }

    static nonisolated func timeTickInterval(
        after date: Date,
        showsSeconds: Bool,
        in timeZone: TimeZone = .nepal
    ) -> TimeInterval {
        let period: TimeInterval = showsSeconds ? 1 : 60
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
