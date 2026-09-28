// SPDX-License-Identifier: GPL-3.0-or-later
import Foundation

/// Every SF Symbol the app uses, named once.
///
/// Centralised for two reasons. An unresolvable name renders as *nothing*, with
/// no error and no fallback, so a typo is invisible until someone looks at the
/// screen; `SymbolTests` resolves every name so a typo fails the suite instead.
/// And a symbol earns its place by reinforcing its label rather than decorating
/// it, so the pairing is written down where a reviewer will read it — which is
/// what caught `person` sitting beside "Local", reading as a user account
/// rather than a place.
///
/// Per ADR-0004 the app uses SF Symbols throughout, and rendering mode is chosen
/// per surface for contrast against Liquid Glass: hierarchical for section
/// headers, monochrome for small inline icons beside text.
enum Symbols {
    /// Section header for the today block.
    static let today = "calendar"

    /// Section header for the converter.
    static let converter = "arrow.left.arrow.right"

    /// "Nepal Time" — the row's distinguishing word is Time.
    static let nepalTime = "clock"

    /// "Local" — the row's distinguishing word is place, and `location` is the
    /// macOS convention for *this place* (Maps, Location Services in System
    /// Settings). Optically identical to `clock` at the size the popover uses,
    /// so the two rows sit on one baseline. `person` was wrong here: it reads
    /// as a user or account, which is a different concept than the label.
    static let localTime = "location"

    /// "Launch at login" — the conventional glyph for run-at-startup.
    static let launchAtLogin = "power"

    /// "Settings…" — the standard macOS Settings glyph.
    static let settings = "gearshape"

    /// "About NepalKit" — the standard macOS information glyph.
    static let about = "info.circle"

    static let all: [String] = [
        today, converter, nepalTime, localTime, launchAtLogin, settings, about,
    ]
}
