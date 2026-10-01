// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Dibas Sigdel
import AppIntents
import NepalKitCore

/// Converts a Bikram Sambat date to Gregorian. A Bikram Sambat date is a
/// civil day, not an instant, so the parameters are day, month, and year —
/// never a `Date` (ticket 02).
struct BikramSambatToGregorianIntent: AppIntent {
    static let title: LocalizedStringResource = "Convert a Bikram Sambat date to Gregorian"

    static var description: IntentDescription {
        IntentDescription("Converts a Bikram Sambat date to its Gregorian date.")
    }

    static let supportedModes: IntentModes = .background

    @Parameter(title: "Day", requestValueDialog: IntentDialog("Which day of the month?"))
    var day: Int

    @Parameter(title: "Month", requestValueDialog: IntentDialog("Which Bikram Sambat month?"))
    var month: BikramSambatMonth

    @Parameter(title: "Year", requestValueDialog: IntentDialog("Which Bikram Sambat year?"))
    var year: Int

    static var parameterSummary: some ParameterSummary {
        Summary {
            \.$day
            \.$month
            \.$year
        }
    }

    func perform() async throws -> some IntentResult & ReturnsValue<Date> & ProvidesDialog {
        let dataset = AppData.dataset
        // Range first, then the month's real length — the dataset supplies
        // every number, and intent code hard-codes none of them (ticket 03).
        guard dataset.supportedRange.contains(year) else {
            throw SiriIntentError(dialog: Self.outOfRangeDialog(in: dataset))
        }
        let lengths = dataset.monthLengths(for: year)
        let monthLength = lengths.flatMap { month.rawValue <= $0.count ? $0[month.rawValue - 1] : nil }
        guard let monthLength, (1 ... monthLength).contains(day) else {
            let name = monthName(month: month.rawValue, style: SettingsStore().settings.monthNames)
            throw SiriIntentError(dialog: "There is no \(day) \(name) \(IntentAnswers.number(year)) — \(name) \(IntentAnswers.number(year)) has \(monthLength ?? 0) days.")
        }
        guard let ad = bsToAD(BSDay(year: year, month: month.rawValue, day: day), in: dataset) else {
            throw SiriIntentError(dialog: Self.outOfRangeDialog(in: dataset))
        }
        guard let instant = noonUTC(for: ad) else {
            throw SiriIntentError(dialog: "NepalKit couldn't build that date.")
        }
        return .result(value: instant, dialog: IntentDialog(Self.successDialog(ad)))
    }

    /// The full boundary — both calendars — because neither side of an
    /// out-of-range Bikram Sambat date is convertible. Dataset numbers only.
    static func outOfRangeDialog(in dataset: CalendarDataset) -> LocalizedStringResource {
        let end = dataset.gregorianEnd ?? dataset.anchorAD
        return "NepalKit's data covers Bikram Sambat \(IntentAnswers.number(dataset.supportedRange.lowerBound)) through \(IntentAnswers.number(dataset.supportedRange.upperBound)) — \(IntentAnswers.spoken(dataset.anchorAD)) to \(IntentAnswers.spoken(end)). That date is outside it."
    }

    /// The spoken answer for a successful conversion — extracted beside the
    /// failure dialogs so the wording is testable without running the intent.
    static func successDialog(_ ad: GADay) -> LocalizedStringResource {
        "\(IntentAnswers.weekdayPrefix(weekday(of: ad)))\(IntentAnswers.spoken(ad))."
    }
}
