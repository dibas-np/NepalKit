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

    init(now: Date = .now, refreshInterval: TimeInterval = 30) {
        self.now = now
        // The closure captures self weakly, so nothing to tear down: the timer
        // lives on the main run loop and dies with the process.
        timer = scheduledMainActorTimer(withTimeInterval: refreshInterval, repeats: true) { [weak self] in
            self?.now = .now
        }
        scheduleMidnightFire()
    }

    private func scheduleMidnightFire() {
        midnightTimer?.invalidate()
        guard let nextMidnight = nextNPTMidnight(after: .now) else { return }
        // +1s so the NPT civil day has definitively rolled over.
        let interval = max(1, nextMidnight.timeIntervalSince(.now) + 1)
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
    func title(settings: DisplaySettings, in dataset: CalendarDataset = .v2) -> String {
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
    func spokenTitle(settings: DisplaySettings, in dataset: CalendarDataset = .v2) -> String {
        SpokenDate.menuBar(
            today: todayBS(now: now, in: dataset),
            monthNames: settings.monthNames,
            dataset: dataset
        )
    }
}
