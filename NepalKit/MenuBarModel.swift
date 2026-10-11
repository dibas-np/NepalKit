// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Dibas Sigdel
import AppKit
import Foundation
import Observation
import NepalKitCore

/// Drives the menu-bar label's periodic refresh.
///
/// Note: a `TimelineView` inside a `MenuBarExtra` label sends this SwiftUI
/// version into a runaway launch loop - `makeMenuBarExtras` ->
/// `updateConfiguration` -> `invalidateProperties` spins at 100% CPU and
/// climbs into gigabytes, so the app never finishes launching. The label
/// therefore reads observable state refreshed by a timer instead.
///
/// The 30s poll keeps the label fresh cheaply; a one-shot midnight timer
/// fires just after the next Nepal Time midnight so the Bikram Sambat date
/// flips within ~1s (User Story 6), then reschedules itself.
///
/// When the title shows the time, a third timer ticks at each Nepal Time
/// minute boundary (each second with seconds shown), aligned to the boundary
/// rather than started on an arbitrary phase, so the clock changes when the
/// minute does and not up to a minute late. It exists only while the time is
/// shown: a menu-bar app that redraws every second for a date that changes
/// once a day would be spending the user's battery on nothing.
///
/// Timer intervals do not advance while the Mac sleeps, and a system clock
/// change moves the wall clock under them, so both are observed: either one
/// re-reads the clock and reschedules the midnight fire and the time tick, rather than leaving
/// yesterday's date up until the next poll.
@MainActor
@Observable
final class MenuBarModel {
    private(set) var now = Date.now
    /// The menu-bar title's optional parts. Owned here rather than beside the
    /// display settings because it is the one setting that changes how this
    /// model schedules its timers.
    private(set) var format: MenuBarFormat

    private var timer: Timer?
    private var midnightTimer: Timer?
    private var timeTickTimer: Timer?
    private let refreshes: Bool
    private let schedulesMidnightFire: Bool
    private let store: SettingsStore?
    /// Wake and clock-change observations, paired with the center each was
    /// added to, so `deinit` can remove exactly what `init` added.
    private var clockObservers: [(center: NotificationCenter, token: any NSObjectProtocol)] = []

    /// - Parameter refreshes: whether to advance `now` from the system clock —
    ///   the poll, and the wake and clock-change observers. Production keeps the
    ///   default; a caller that only needs a fixed instant passes `false`.
    /// - Parameter schedulesMidnightFire: production keeps the default; tests
    ///   that do not exercise the midnight flip pass `false` so they do not
    ///   leave real one-shot timers behind.
    /// - Parameter store: where the menu-bar format is read from and saved to.
    ///   Nil keeps the format in memory only, starting at `.standard`. Unlike
    ///   `DisplaySettingsModel`, nil does not mean `SettingsStore()`: this model
    ///   is built by many tests that assert the standard title, and reading the
    ///   developer's own preferences there would make them pass or fail by
    ///   whatever the Menu Bar tab was last set to. The app passes the store.
    /// - Parameter workspaceNotifications: where wake is posted; defaults to
    ///   `NSWorkspace.shared.notificationCenter`. Injected so a test can post a
    ///   wake without sleeping the Mac.
    /// - Parameter systemNotifications: where a system clock change is posted;
    ///   defaults to `NotificationCenter.default`.
    ///
    /// Both centers default in the body rather than the signature, for the same
    /// reason as `LoginItemModel`: a default argument is evaluated in a
    /// nonisolated context.
    init(
        now: Date = .now,
        refreshInterval: TimeInterval = 30,
        refreshes: Bool = true,
        schedulesMidnightFire: Bool = true,
        store: SettingsStore? = nil,
        workspaceNotifications: NotificationCenter? = nil,
        systemNotifications: NotificationCenter? = nil
    ) {
        self.now = now
        self.format = store?.menuBarFormat ?? .standard
        self.refreshes = refreshes
        self.schedulesMidnightFire = schedulesMidnightFire
        self.store = store
        if refreshes {
            timer = scheduledMainActorTimer(withTimeInterval: refreshInterval, repeats: true) { [weak self] in
                self?.now = .now
            }
            observeClockDiscontinuity(
                NSWorkspace.didWakeNotification,
                on: workspaceNotifications ?? NSWorkspace.shared.notificationCenter
            )
            observeClockDiscontinuity(.NSSystemClockDidChange, on: systemNotifications ?? .default)
        }
        if schedulesMidnightFire {
            scheduleMidnightFire()
        }
        scheduleTimeTick()
    }

    /// The run loop retains a scheduled timer and a center retains its block, so
    /// neither goes away with the model unless it is let go of here.
    isolated deinit {
        timer?.invalidate()
        midnightTimer?.invalidate()
        timeTickTimer?.invalidate()
        for observer in clockObservers {
            observer.center.removeObserver(observer.token)
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

    /// Re-reads the clock after the Mac wakes or the system clock is changed.
    /// The midnight fire and the time tick are rescheduled because their
    /// intervals were measured against a clock that has since jumped.
    func refreshAfterClockDiscontinuity() {
        now = .now
        if schedulesMidnightFire {
            scheduleMidnightFire()
        }
        scheduleTimeTick()
    }

    /// Persists a new menu-bar format and applies it at once: the label reads
    /// `format`, so it redraws on this assignment rather than at the next poll.
    ///
    /// The clock is re-read first when this model refreshes, because `now` can
    /// be up to a poll interval old and switching the time on would otherwise
    /// show a minute that has already passed until the first tick.
    func save(_ format: MenuBarFormat) {
        store?.save(format)
        if refreshes {
            now = .now
        }
        self.format = format
        scheduleTimeTick()
    }

    /// Whether the minute or second tick is running. Read by tests; the timer
    /// itself stays private.
    var isTickingForTime: Bool {
        timeTickTimer != nil
    }

    /// Seconds from `date` until just after the next NPT midnight (+1s so the
    /// civil day has definitively rolled over). Internal and pure so the flip's
    /// scheduling is assertable without real timers.
    static nonisolated func midnightFireInterval(after date: Date) -> TimeInterval? {
        guard let nextMidnight = nextNPTMidnight(after: date) else { return nil }
        return max(1, nextMidnight.timeIntervalSince(date) + 1)
    }

    /// Seconds from `date` to the next Nepal Time minute boundary, or second
    /// boundary when seconds are shown; a full period when `date` is exactly on
    /// one. Internal and pure, like `midnightFireInterval`, so the alignment is
    /// assertable without real timers.
    ///
    /// No guard second is added, unlike the midnight fire: the tick reschedules
    /// from the clock it reads on firing, so a fire that lands a hair early is
    /// followed at once by one that lands after the boundary, whereas a
    /// one-second guard would put the clock a second late every minute.
    static nonisolated func timeTickInterval(after date: Date, showsSeconds: Bool) -> TimeInterval {
        let period: TimeInterval = showsSeconds ? 1 : 60
        // Nepal Time's +5:45 is a whole number of minutes, so the offset does
        // not move a boundary today; it is applied so the alignment is stated
        // in Nepal Time rather than relying on that.
        let nepalSeconds = date.timeIntervalSinceReferenceDate + TimeInterval(nepalTimeZone.secondsFromGMT(for: date))
        let remainder = nepalSeconds.truncatingRemainder(dividingBy: period)
        let elapsed = remainder < 0 ? remainder + period : remainder
        return period - elapsed
    }

    /// Starts, restarts or stops the time tick to match `format`.
    private func scheduleTimeTick() {
        timeTickTimer?.invalidate()
        timeTickTimer = nil
        guard refreshes, format.showsTime else { return }
        let interval = Self.timeTickInterval(after: now, showsSeconds: format.showsSeconds)
        timeTickTimer = scheduledMainActorTimer(withTimeInterval: interval, repeats: false) { [weak self] in
            self?.now = .now
            self?.scheduleTimeTick()
        }
    }

    private func scheduleMidnightFire() {
        midnightTimer?.invalidate()
        guard let interval = Self.midnightFireInterval(after: now) else { return }
        midnightTimer = scheduledMainActorTimer(withTimeInterval: interval, repeats: false) { [weak self] in
            self?.now = .now
            self?.scheduleMidnightFire()
        }
    }
}
