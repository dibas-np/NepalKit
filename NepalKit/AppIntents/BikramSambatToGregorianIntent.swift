// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Dibas Sigdel
import AppIntents
import NepalKitCore

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
        guard dataset.supportedRange.contains(year) else {
            throw SiriIntentError(dialog: Self.outOfRangeDialog(in: dataset))
        }
        let lengths = dataset.monthLengths(for: year)
        let monthLength = lengths.flatMap { month.rawValue <= $0.count ? $0[month.rawValue - 1] : nil }
        guard let monthLength, (1 ... monthLength).contains(day) else {
            let name = BikramSambatDate.monthName(month.rawValue, style: SettingsStore().settings.monthNames)
            throw SiriIntentError(dialog: "There is no \(day) \(name) \(IntentAnswers.number(year)) — \(name) \(IntentAnswers.number(year)) has \(monthLength ?? 0) days.")
        }
        guard let ad = GregorianDate(BikramSambatDate(year: year, month: month.rawValue, day: day), in: dataset) else {
            throw SiriIntentError(dialog: Self.outOfRangeDialog(in: dataset))
        }
        guard let instant = Self.noonInUserCalendar(for: ad) else {
            throw SiriIntentError(dialog: "NepalKit couldn't build that date.")
        }
        return .result(value: instant, dialog: IntentDialog(Self.successDialog(ad, fromProvisionalYear: dataset.isProvisional(year))))
    }

    static func noonInUserCalendar(
        for ad: GregorianDate,
        calendar: Calendar = GregorianToBikramSambatIntent.userGregorian()
    ) -> Date? {
        let components = DateComponents(year: ad.year, month: ad.month, day: ad.day, hour: 12)
        // `Calendar` normalizes impossible components, so the day must read back.
        guard let instant = calendar.date(from: components),
              GregorianToBikramSambatIntent.namedDay(for: instant, calendar: calendar) == ad
        else { return nil }
        return instant
    }

    static func outOfRangeDialog(in dataset: CalendarDataset) -> LocalizedStringResource {
        guard let start = GregorianDate(BikramSambatDate(year: dataset.supportedRange.lowerBound, month: 1, day: 1), in: dataset) else {
            preconditionFailure("Calendar dataset must convert its first supported day")
        }
        let end = dataset.gregorianEnd ?? dataset.anchorGregorian
        return "NepalKit's data covers Bikram Sambat \(IntentAnswers.number(dataset.supportedRange.lowerBound)) through \(IntentAnswers.number(dataset.supportedRange.upperBound)) — \(IntentAnswers.spoken(start)) to \(IntentAnswers.spoken(end)). That date is outside it."
    }

    static func successDialog(_ ad: GregorianDate, fromProvisionalYear: Bool) -> LocalizedStringResource {
        if fromProvisionalYear {
            return "\(IntentAnswers.weekdayPrefix(ad.weekday))\(IntentAnswers.spoken(ad)). That Bikram Sambat year is a provisional projection, not yet in the official Nepali Patro."
        }
        return "\(IntentAnswers.weekdayPrefix(ad.weekday))\(IntentAnswers.spoken(ad))."
    }
}
