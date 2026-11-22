// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Dibas Sigdel

nonisolated extension Strings {
    static let timeZoneSection = "Time"
    static let timeZoneLabel = "Time zone"
    static let timeZoneNepal = "Nepal Time"

    static func timeZoneLocal(zoneName: String) -> String {
        "My time zone (\(zoneName))"
    }

    static let timeZoneFootnote = """
        Decides which day is today, when it rolls over at midnight, and the time \
        shown in the popover and the menu bar. Siri answers by it too. The Watch \
        always follows Nepal Time.
        """

    static func menuBarTimeFootnote(_ reference: TimeReference) -> String {
        switch reference {
        case .nepal: "The time is Nepal Time, whatever your Mac's time zone."
        case .local: "The time is your Mac's time zone, as chosen in General."
        }
    }
}
