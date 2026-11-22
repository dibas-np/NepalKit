// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Dibas Sigdel
import NepalKitCore

/// Spoken text for intent dialogs: always `SpokenDate` form (Latin digits),
/// never the on-screen display form.
nonisolated enum IntentAnswers {
    static func spoken(_ bs: BikramSambatDate, monthNames: MonthNameStyle = SettingsStore().settings.monthNames) -> String {
        SpokenDate.bikramSambat(bs, monthNames: monthNames)
    }

    static func spoken(_ ad: GregorianDate) -> String {
        SpokenDate.gregorian(ad)
    }

    /// The `<weekday>, ` prefix, or "" when the lookup fails.
    static func weekdayPrefix(_ weekday: Int?, monthNames: MonthNameStyle = SettingsStore().settings.monthNames) -> String {
        guard let weekday,
              let name = BikramSambatDate.weekdayName(weekday, style: monthNames)
        else { return "" }
        return "\(name), "
    }

    static func weekdayNameString(_ weekday: Int?, monthNames: MonthNameStyle = SettingsStore().settings.monthNames) -> String? {
        weekday.flatMap { BikramSambatDate.weekdayName($0, style: monthNames) }
    }

    /// Avoids the locale grouping ("2,084") a bare Int gets in a `LocalizedStringResource`.
    static func number(_ value: Int) -> String {
        SpokenDate.number(value)
    }
}
