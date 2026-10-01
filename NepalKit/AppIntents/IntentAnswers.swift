// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Dibas Sigdel
import NepalKitCore

/// Builds the spoken half of the Siri surface — ticket 03's dialog/display
/// split. Dialogs always speak `SpokenDate` form: Latin digits, the
/// configured month-name language. Never the rendered display form, which is
/// the entity's job. The style defaults to the store's cold read and is a
/// parameter so tests can inject it (injection over globals).
nonisolated enum IntentAnswers {
    static func spoken(_ bs: BSDay, monthNames: MonthNameStyle = SettingsStore().settings.monthNames) -> String {
        SpokenDate.bs(bs, monthNames: monthNames)
    }

    static func spoken(_ ad: GADay) -> String {
        SpokenDate.ad(ad)
    }

    /// The `<weekday>, ` prefix, or "" when the lookup fails, so callers can
    /// interpolate unconditionally and the sentence never shows a gap.
    static func weekdayPrefix(_ weekday: Int?, monthNames: MonthNameStyle = SettingsStore().settings.monthNames) -> String {
        guard let weekday,
              let name = weekdayName(for: weekday, style: monthNames)
        else { return "" }
        return "\(name), "
    }

    /// The weekday name for the entity's `weekday` property, or nil when the
    /// lookup fails — the same optionality `SpokenDate.gregorianAnnouncement`
    /// treats as a separate lookup that can fail, not a date that can.
    static func weekdayNameString(_ weekday: Int?, monthNames: MonthNameStyle = SettingsStore().settings.monthNames) -> String? {
        weekday.flatMap { weekdayName(for: $0, style: monthNames) }
    }

    /// Numbers inside dialogs speak through `SpokenDate` — never a bare Int,
    /// which a `LocalizedStringResource` formats with locale grouping
    /// ("2,084"), wrong in a spoken year or range boundary.
    static func number(_ value: Int) -> String {
        SpokenDate.number(value)
    }
}
