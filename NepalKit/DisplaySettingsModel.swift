import Foundation
import Observation
import NepalKitCore

/// Observable display settings: persisted through SettingsStore, published
/// so the menu-bar extra and popover refresh instantly on change.
@Observable
final class DisplaySettingsModel {
    private(set) var settings: DisplaySettings

    private let store: SettingsStore

    init(store: SettingsStore = SettingsStore()) {
        self.store = store
        self.settings = store.settings
    }

    func save(_ settings: DisplaySettings) {
        store.save(settings)
        self.settings = settings
    }

    func save(digits: DigitScript) {
        save(DisplaySettings(digits: digits, monthNames: settings.monthNames))
    }

    func save(monthNames: MonthNameStyle) {
        save(DisplaySettings(digits: settings.digits, monthNames: monthNames))
    }
}
