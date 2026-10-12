// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Dibas Sigdel

/// The time-reference setting in General (ADR-0017), in a file of its own so
/// `Strings.swift` stays under the length limit.
nonisolated extension Strings {
    static let timeZoneSection = "Time"
    static let timeZoneLabel = "Time zone"
    static let timeZoneNepal = "Nepal Time"

    /// Names the zone the option would follow, because "my time zone" alone
    /// asks the reader to know what their Mac is set to.
    static func timeZoneLocal(zoneName: String) -> String {
        "My time zone (\(zoneName))"
    }

    /// Lists everything the choice moves, and that the Watch (no settings) does
    /// not.
    static let timeZoneFootnote = """
        Decides which day is today, when it rolls over at midnight, and the time \
        shown in the popover and the menu bar. Siri answers by it too. The Watch \
        always follows Nepal Time.
        """

    /// Says which clock the menu-bar time is, since beside the system clock it
    /// reads as the same one.
    static func menuBarTimeFootnote(_ reference: TimeReference) -> String {
        switch reference {
        case .nepal: "The time is Nepal Time, whatever your Mac's time zone."
        case .local: "The time is your Mac's time zone, as chosen in General."
        }
    }
}
