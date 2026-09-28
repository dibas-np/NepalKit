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
@MainActor
@Observable
final class MenuBarModel {
    private(set) var now = Date()

    private var timer: Timer?

    init(now: Date = Date(), refreshInterval: TimeInterval = 30) {
        self.now = now
        // The closure captures self weakly, so nothing to tear down: the timer
        // lives on the main run loop and dies with the process.
        timer = Timer.scheduledTimer(withTimeInterval: refreshInterval, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.now = Date() }
        }
    }

    /// Short Bikram Sambat date for the menu-bar extra, honoring the given display settings.
    func title(settings: DisplaySettings) -> String {
        guard let today = todayBS(now: now, in: .v1) else { return "—" }
        return formatBSShort(today, settings: settings)
    }
}
