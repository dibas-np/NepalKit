// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Dibas Sigdel
import AppIntents
import NepalKitCore

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
        if let bs = BikramSambatDate(ad, in: dataset) {
            guard let entity = BikramSambatDateEntity(bsDay: bs) else {
                throw SiriIntentError(dialog: "NepalKit couldn't build that date.")
            }
            return .result(value: entity, dialog: IntentDialog(Self.successDialog(bs, weekday: ad.weekday, in: dataset)))
        }
        if let invalid = Self.invalidDayDialog(ad) {
            throw SiriIntentError(dialog: invalid)
        }
        throw SiriIntentError(dialog: Self.outOfRangeDialog(ad, in: dataset))
    }

    /// `Calendar.current` could carry a non-Gregorian
    /// identifier whose year components would misparse every conversion.
    static func userGregorian() -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        return calendar
    }

    static func namedDay(for date: Date, calendar: Calendar = GregorianToBikramSambatIntent.userGregorian()) -> GregorianDate? {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        guard let year = components.year, let month = components.month, let day = components.day else {
            return nil
        }
        return GregorianDate(year: year, month: month, day: day)
    }

    static func invalidDayDialog(_ ad: GregorianDate) -> LocalizedStringResource? {
        guard let length = GregorianDate.daysInMonth(year: ad.year, month: ad.month), length < ad.day else {
            return nil
        }
        let name = GregorianDate.monthName(ad.month)
        return "There is no \(ad.day) \(name) \(IntentAnswers.number(ad.year)) — \(name) \(IntentAnswers.number(ad.year)) has \(length) days."
    }

    static func outOfRangeDialog(_ ad: GregorianDate, in dataset: CalendarDataset) -> LocalizedStringResource {
        if let end = dataset.gregorianEnd, ad > end {
            return "NepalKit's Bikram Sambat data covers \(IntentAnswers.number(dataset.supportedRange.lowerBound)) through \(IntentAnswers.number(dataset.supportedRange.upperBound)) — up to \(IntentAnswers.spoken(end)). That date is outside it."
        }
        guard let start = GregorianDate(BikramSambatDate(year: dataset.supportedRange.lowerBound, month: 1, day: 1), in: dataset) else {
            preconditionFailure("Calendar dataset must convert its first supported day")
        }
        return "NepalKit's Bikram Sambat data covers \(IntentAnswers.number(dataset.supportedRange.lowerBound)) through \(IntentAnswers.number(dataset.supportedRange.upperBound)) — back to \(IntentAnswers.spoken(start)). That date is outside it."
    }

    static func successDialog(_ bs: BikramSambatDate, weekday: Int?, in dataset: CalendarDataset) -> LocalizedStringResource {
        if dataset.isProvisional(bs.year) {
            return "\(IntentAnswers.weekdayPrefix(weekday))\(IntentAnswers.spoken(bs)). That year is a provisional projection, not yet in the official Nepali Patro."
        }
        return "\(IntentAnswers.weekdayPrefix(weekday))\(IntentAnswers.spoken(bs))."
    }
}
