// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Dibas Sigdel
import AppIntents
import NepalKitCore

/// Answers today's date in Bikram Sambat. Anchored to Nepal Time: "today"
/// means Nepal's current calendar date (CONTEXT.md's Today entry, ticket 02).
struct TodayInBikramSambatIntent: AppIntent {
    static let title: LocalizedStringResource = "What is today's Nepali date"

    static var description: IntentDescription {
        IntentDescription("Speaks today's date in Bikram Sambat, Nepal's calendar.")
    }

    static let supportedModes: IntentModes = .background

    static var parameterSummary: some ParameterSummary { Summary() }

    func perform() async throws -> some IntentResult & ReturnsValue<BikramSambatDateEntity> & ProvidesDialog {
        let dataset = AppData.dataset
        let now = Date()
        guard let bs = todayBS(now: now, in: dataset) else {
            throw SiriIntentError(dialog: Self.beyondRangeDialog(now: now, in: dataset))
        }
        let bsWeekday = weekday(of: bs, in: dataset)
        guard let entity = BikramSambatDateEntity(bsDay: bs) else {
            throw SiriIntentError(dialog: "NepalKit couldn't build that date.")
        }
        return .result(value: entity, dialog: "Today is \(IntentAnswers.weekdayPrefix(bsWeekday))\(IntentAnswers.spoken(bs)).")
    }

    /// Past the supported range: the boundary statement names the last
    /// supported year from the dataset, and Gregorian today stays
    /// answerable (ticket 03, failure shape 1). Every number comes from the
    /// dataset; none is hard-coded.
    static func beyondRangeDialog(now: Date, in dataset: CalendarDataset) -> LocalizedStringResource {
        let gregorianToday = todayAD(now: now)
        let prefix = IntentAnswers.weekdayPrefix(gregorianToday.flatMap { weekday(of: $0) })
        let spokenToday = gregorianToday.map { IntentAnswers.spoken($0) } ?? ""
        // Years interpolate as strings: a bare Int formats with locale
        // grouping ("2,084"), which is wrong in a spoken year.
        return "NepalKit's Bikram Sambat data covers up to the year \(String(dataset.supportedRange.upperBound)). Today is \(prefix)\(spokenToday)."
    }
}
