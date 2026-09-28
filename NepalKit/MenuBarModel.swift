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
    private(set) var now = Date()

    private var timer: Timer?
    private var midnightTimer: Timer?

    init(now: Date = Date(), refreshInterval: TimeInterval = 30) {
        self.now = now
        // The closure captures self weakly, so nothing to tear down: the timer
        // lives on the main run loop and dies with the process.
        timer = Timer.scheduledTimer(withTimeInterval: refreshInterval, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.now = Date() }
        }
        scheduleMidnightFire()
    }

    private func scheduleMidnightFire() {
        midnightTimer?.invalidate()
        guard let nextMidnight = nextNPTMidnight(after: Date()) else { return }
        // +1s so the NPT civil day has definitively rolled over.
        let interval = max(1, nextMidnight.timeIntervalSince(Date()) + 1)
        midnightTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.now = Date()
                self?.scheduleMidnightFire()
            }
        }
    }

    /// Short Bikram Sambat date for the menu-bar extra, honoring the given display settings.
    ///
    /// Past the dataset's supported range this returns a compact boundary marker
    /// rather than a bare "—". The menu bar has no room to explain itself and
    /// deliberately carries no warning badge, so the marker's job is only to stop
    /// the absence reading as a bug; the popover is where the boundary is
    /// actually stated in words.
    func title(settings: DisplaySettings, in dataset: CalendarDataset = .v1) -> String {
        guard let today = todayBS(now: now, in: dataset) else {
            return Strings.menuBarBeyondRange
        }
        return formatBSShort(today, settings: settings)
    }
}
