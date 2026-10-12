// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Dibas Sigdel
import Foundation
import NepalKitCore

/// Which clock the Mac app's "today" follows: Nepal Time, or the Mac's own time
/// zone (ADR-0017).
///
/// It decides which day is today, when that day rolls over, and which time the
/// header and the menu bar show. The Watch has no settings and stays on Nepal
/// Time. `nonisolated` because the Siri intents read it off the main actor.
nonisolated enum TimeReference: String, CaseIterable, Sendable {
    case nepal
    case local

    /// The zone this reference names. `.autoupdatingCurrent` rather than
    /// `.current`, so a Mac that changes zone mid-session is followed rather than
    /// held to the zone it launched in.
    var timeZone: TimeZone {
        switch self {
        case .nepal: nepalTimeZone
        case .local: .autoupdatingCurrent
        }
    }

    /// The name of the Mac's zone for the setting's label: "Eastern Time"
    /// rather than "America/New_York", falling back to the identifier where
    /// the system has no name for it.
    static func localZoneName(_ zone: TimeZone = .autoupdatingCurrent, locale: Locale = .current) -> String {
        zone.localizedName(for: .generic, locale: locale) ?? zone.identifier
    }
}
