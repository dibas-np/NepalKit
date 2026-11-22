// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Dibas Sigdel
import Foundation
import NepalKitCore

/// Which clock the Mac app's "today" follows: Nepal Time, or the Mac's own time
/// zone.
///
/// `nonisolated` because the Siri intents read it off the main actor.
nonisolated enum TimeReference: String, CaseIterable, Sendable {
    case nepal
    case local

    /// `.autoupdatingCurrent` so a mid-session zone change is followed.
    var timeZone: TimeZone {
        switch self {
        case .nepal: TimeZone.nepal
        case .local: .autoupdatingCurrent
        }
    }

    /// The localized name of the Mac's zone, e.g. "Eastern Time".
    static func localZoneName(_ zone: TimeZone = .autoupdatingCurrent, locale: Locale = .current) -> String {
        zone.localizedName(for: .generic, locale: locale) ?? zone.identifier
    }
}
