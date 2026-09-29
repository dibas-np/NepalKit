// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Dibas Sigdel
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
@MainActor
@Observable
final class MenuBarModel {
    private(set) var now = Date.now

    private var timer: Timer?
    private var midnightTimer: Timer?

    /// - Parameter refreshes: whether to schedule the timer that advances `now`
    ///   from the system clock. Production keeps the default; a caller that only
    ///   needs a fixed instant passes `false`. Nothing invalidates either timer —
    ///   the run loop retains them and a weak capture only lets this model go —
    ///   so both would otherwise outlive the caller.
    /// - Parameter schedulesMidnightFire: production keeps the default; tests
    ///   that do not exercise the midnight flip pass `false` so they do not
    ///   leave real one-shot timers behind.
    init(now: Date = .now, refreshInterval: TimeInterval = 30, refreshes: Bool = true, schedulesMidnightFire: Bool = true) {
        self.now = now
        if refreshes {
            timer = scheduledMainActorTimer(withTimeInterval: refreshInterval, repeats: true) { [weak self] in
                self?.now = .now
            }
        }
        if schedulesMidnightFire {
            scheduleMidnightFire()
        }
    }

    /// Seconds from `date` until just after the next NPT midnight (+1s so the
    /// civil day has definitively rolled over). Internal and pure so the flip's
    /// scheduling is assertable without real timers.
    static nonisolated func midnightFireInterval(after date: Date) -> TimeInterval? {
        guard let nextMidnight = nextNPTMidnight(after: date) else { return nil }
        return max(1, nextMidnight.timeIntervalSince(date) + 1)
    }

    private func scheduleMidnightFire() {
        midnightTimer?.invalidate()
        guard let interval = Self.midnightFireInterval(after: now) else { return }
        midnightTimer = scheduledMainActorTimer(withTimeInterval: interval, repeats: false) { [weak self] in
            self?.now = .now
            self?.scheduleMidnightFire()
        }
    }

    /// Short Bikram Sambat date for the menu-bar extra, honoring the given display settings.
    ///
    /// Past the dataset's supported range this returns a compact boundary marker
    /// rather than a bare "—". The menu bar has no room to explain itself and
    /// deliberately carries no warning badge, so the marker's job is only to stop
    /// the absence reading as a bug; the popover is where the boundary is
    /// actually stated in words.
    func title(settings: DisplaySettings, in dataset: CalendarDataset = AppData.dataset) -> String {
        guard let today = todayBS(now: now, in: dataset) else {
            return Strings.menuBarBeyondRange
        }
        return formatBSShort(today, settings: settings)
    }

    /// What VoiceOver announces for the menu-bar extra.
    ///
    /// Separate from `title` because the two answer different questions. The
    /// title is the menu bar's few pixels of space and carries the bare date; the
    /// announcement is a sentence, so it can name the app and say the date in a
    /// form a voice can actually pronounce. Splitting them is what keeps the
    /// menu bar from being made worse for everybody in order to help someone
    /// using speech — the visual stays exactly as short as it was.
    func spokenTitle(settings: DisplaySettings, in dataset: CalendarDataset = AppData.dataset) -> String {
        SpokenDate.menuBar(
            today: todayBS(now: now, in: dataset),
            monthNames: settings.monthNames,
            dataset: dataset
        )
    }
}
