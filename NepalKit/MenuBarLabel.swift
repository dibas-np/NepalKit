import Foundation
import NepalKitCore

/// Short Bikram Sambat date for the menu-bar extra, honoring the given display settings.
func menuBarTitle(now: Date, settings: DisplaySettings) -> String {
    guard let today = todayBS(now: now, in: .v1) else { return "—" }
    return formatShort(today, settings: settings)
}
