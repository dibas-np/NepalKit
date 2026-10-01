// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Dibas Sigdel
import AppIntents
import NepalKitCore

/// Converts a Gregorian date to Bikram Sambat. The named calendar day
/// survives: the resolved instant is read in the user's current time zone and
/// time-of-day is discarded (ticket 02) — only *today* is Nepal-Time-anchored.
struct GregorianToBikramSambatIntent: AppIntent {
    static let title: LocalizedStringResource = "Convert a date to Bikram Sambat"

    static var description: IntentDescription {
        IntentDescription("Converts a Gregorian date to its Bikram Sambat date.")
    }

    static let supportedModes: IntentModes = .background

    @Parameter(title: "Date", requestValueDialog: IntentDialog("Which date should NepalKit convert?"))
    var date: Date

    static var parameterSummary: some ParameterSummary {
        Summary {
            \.$date
        }
    }

    func perform() async throws -> some IntentResult & ReturnsValue<BikramSambatDateEntity> & ProvidesDialog {
        let dataset = AppData.dataset
        guard let ad = Self.namedDay(for: date) else {
            throw SiriIntentError(dialog: "NepalKit couldn't read that date.")
        }
        if let bs = adToBS(ad, in: dataset) {
            guard let entity = BikramSambatDateEntity(
                bsDay: bs,
                weekday: IntentAnswers.weekdayNameString(weekday(of: ad))
            ) else {
                throw SiriIntentError(dialog: "NepalKit couldn't build that date.")
            }
            return .result(value: entity, dialog: IntentDialog(Self.successDialog(bs, weekday: weekday(of: ad))))
        }
        // No table row: either the day does not exist, or the date sits
        // outside the table. Both wordings speak dataset numbers only.
        if let invalid = Self.invalidDayDialog(ad) {
            throw SiriIntentError(dialog: invalid)
        }
        throw SiriIntentError(dialog: Self.outOfRangeDialog(ad, in: dataset))
    }

    /// The user's time zone on the Gregorian calendar — the spec's reading of
    /// "the calendar day Siri named". `Calendar.current` would also adopt the
    /// device's calendar identifier (Buddhist, Islamic, ...), whose year
    /// components would misparse every conversion into out-of-range.
    static func userGregorian() -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        return calendar
    }

    /// The calendar day the resolved instant names in the given calendar,
    /// time-of-day discarded. Conversions are day-granular: only *today* is
    /// Nepal-Time-anchored; a named conversion input is a calendar day as
    /// spoken, independent of Nepal Time.
    static func namedDay(for date: Date, calendar: Calendar = GregorianToBikramSambatIntent.userGregorian()) -> GADay? {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        guard let year = components.year, let month = components.month, let day = components.day else {
            return nil
        }
        return GADay(year: year, month: month, day: day)
    }

    /// The month-length statement for a Gregorian input that names no civil
    /// day (30 February), or nil when the day exists. Checked before the
    /// range, so an impossible day is never reported as out-of-range.
    static func invalidDayDialog(_ ad: GADay) -> LocalizedStringResource? {
        guard let length = daysInGregorianMonth(year: ad.year, month: ad.month), length < ad.day else {
            return nil
        }
        let name = gregorianMonthName(ad.month)
        return "There is no \(ad.day) \(name) \(IntentAnswers.number(ad.year)) — \(name) \(IntentAnswers.number(ad.year)) has \(length) days."
    }

    /// The boundary dates come from the dataset — never a literal.
    static func outOfRangeDialog(_ ad: GADay, in dataset: CalendarDataset) -> LocalizedStringResource {
        if let end = dataset.gregorianEnd, ad > end {
            return "NepalKit's Bikram Sambat data covers \(IntentAnswers.number(dataset.supportedRange.lowerBound)) through \(IntentAnswers.number(dataset.supportedRange.upperBound)) — up to \(IntentAnswers.spoken(end)). That date is outside it."
        }
        guard let start = bsToAD(BSDay(year: dataset.supportedRange.lowerBound, month: 1, day: 1), in: dataset) else {
            preconditionFailure("Calendar dataset must convert its first supported day")
        }
        return "NepalKit's Bikram Sambat data covers \(IntentAnswers.number(dataset.supportedRange.lowerBound)) through \(IntentAnswers.number(dataset.supportedRange.upperBound)) — back to \(IntentAnswers.spoken(start)). That date is outside it."
    }

    /// The spoken answer for a successful conversion — extracted beside the
    /// failure dialogs so the wording is testable without running the intent.
    static func successDialog(_ bs: BSDay, weekday: Int?) -> LocalizedStringResource {
        "\(IntentAnswers.weekdayPrefix(weekday))\(IntentAnswers.spoken(bs))."
    }
}
