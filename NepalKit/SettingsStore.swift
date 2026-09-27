import Foundation

/// Persists the two display axes in UserDefaults. The store stays
/// dumb and injectable so persistence is testable without the app running.
public struct SettingsStore {
    public static let digitScriptKey = "digitScript"
    public static let monthNameStyleKey = "monthNameStyle"

    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public var settings: DisplaySettings {
        let digits = DigitScript(rawValue: defaults.string(forKey: Self.digitScriptKey) ?? "") ?? .latin
        let monthNames = MonthNameStyle(rawValue: defaults.string(forKey: Self.monthNameStyleKey) ?? "") ?? .transliterated
        return DisplaySettings(digits: digits, monthNames: monthNames)
    }

    public func save(_ settings: DisplaySettings) {
        defaults.set(settings.digits.rawValue, forKey: Self.digitScriptKey)
        defaults.set(settings.monthNames.rawValue, forKey: Self.monthNameStyleKey)
    }
}
