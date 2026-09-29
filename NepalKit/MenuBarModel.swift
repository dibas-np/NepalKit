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
    /// rather than a bare "—". That marker is a statement of fact, not a warning:
    /// the menu bar has no room to explain itself, so its job is only to stop the
    /// absence reading as a bug; the popover is where the boundary is stated in
    /// words.
    ///
    /// - Parameter updateAvailable: prefixes a warning marker, which is a
    ///   different thing from the boundary marker above — this one asks the user
    ///   to do something. The date is kept rather than replaced, because showing
    ///   today's date is the reason the item is in the menu bar at all, and an
    ///   update alert raised by a windowless app is easy to never notice.
    func title(
        settings: DisplaySettings,
        in dataset: CalendarDataset = AppData.dataset,
        updateAvailable: Bool = false
    ) -> String {
        guard let today = todayBS(now: now, in: dataset) else {
            return Strings.menuBarBeyondRange
        }
        let date = formatBSShort(today, settings: settings)
        return updateAvailable ? Strings.menuBarUpdateMarker + date : date
    }

    /// What VoiceOver announces for the menu-bar extra.
    ///
    /// Separate from `title` because the two answer different questions. The
    /// title is the menu bar's few pixels of space and carries the bare date; the
    /// announcement is a sentence, so it can name the app and say the date in a
    /// form a voice can actually pronounce. Splitting them is what keeps the
    /// menu bar from being made worse for everybody in order to help someone
    /// using speech — the visual stays exactly as short as it was.
    ///
    /// The update is announced as words rather than as the marker glyph, for the
    /// same reason the date is: a voice cannot read "!", and the marker is the
    /// one thing on this surface that changes what the user should do.
    func spokenTitle(
        settings: DisplaySettings,
        in dataset: CalendarDataset = AppData.dataset,
        updateAvailable: Bool = false
    ) -> String {
        let date = SpokenDate.menuBar(
            today: todayBS(now: now, in: dataset),
            monthNames: settings.monthNames,
            dataset: dataset
        )
        return updateAvailable ? "\(Strings.updateAvailableSpoken). \(date)" : date
    }
}
