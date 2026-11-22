// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Dibas Sigdel
import Foundation
import NepalKitCore

nonisolated enum TimeReference: String, CaseIterable, Sendable {
    case nepal
    case local

    var timeZone: TimeZone {
        switch self {
        case .nepal: TimeZone.nepal
        case .local: .autoupdatingCurrent
        }
    }

    static func localZoneName(_ zone: TimeZone = .autoupdatingCurrent, locale: Locale = .current) -> String {
        zone.localizedName(for: .generic, locale: locale) ?? zone.identifier
    }
}
