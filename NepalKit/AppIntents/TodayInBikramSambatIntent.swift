// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Dibas Sigdel
import AppIntents
import NepalKitCore

/// Answers today's date in Bikram Sambat. "Today" is the current calendar date
/// in the zone the user's time reference names: Nepal Time unless they chose
/// their own (CONTEXT.md's Today entry, ticket 02, ADR-0017).
struct TodayInBikramSambatIntent: AppIntent {
    static let title: LocalizedStringResource = "What is today's Nepali date"

    static var description: IntentDescription {
        IntentDescription("Speaks today's date in Bikram Sambat, Nepal's calendar.")
    }

    static let supportedModes: IntentModes = .background

    static var parameterSummary: some ParameterSummary { Summary() }

    func perform() async throws -> some IntentResult & ReturnsValue<BikramSambatDateEntity> & ProvidesDialog {
        let answer = try Self.answer(now: Date(), in: AppData.dataset)
        return .result(value: answer.entity, dialog: IntentDialog(answer.dialog))
    }

    /// Today's entity and dialog for `now` in the user's time reference.
    /// Extracted so a test can pass the instant and zone rather than the wall
    /// clock and the developer's preferences.
    static func answer(
        now: Date,
        in dataset: CalendarDataset,
        timeZone: TimeZone = SettingsStore().timeReference.timeZone
    ) throws -> (entity: BikramSambatDateEntity, dialog: LocalizedStringResource) {
        guard let bs = todayBS(now: now, timeZone: timeZone, in: dataset) else {
            throw SiriIntentError(dialog: beyondRangeDialog(now: now, timeZone: timeZone, in: dataset))
        }
        guard let entity = BikramSambatDateEntity(bsDay: bs) else {
            throw SiriIntentError(dialog: "NepalKit couldn't build that date.")
        }
        return (entity, successDialog(bs, weekday: weekday(of: bs, in: dataset), in: dataset))
    }

    /// The spoken answer for today, extracted so the wording (including the
    /// provisional clause) is testable without the wall clock.
    static func successDialog(_ bs: BSDay, weekday: Int?, in dataset: CalendarDataset) -> LocalizedStringResource {
        if dataset.isProvisional(bs.year) {
            return "Today is \(IntentAnswers.weekdayPrefix(weekday))\(IntentAnswers.spoken(bs)). This year is a provisional projection, not yet in the official Nepali Patro."
        }
        return "Today is \(IntentAnswers.weekdayPrefix(weekday))\(IntentAnswers.spoken(bs))."
    }

    /// Past the supported range: the boundary statement names the last
    /// supported year from the dataset, and Gregorian today stays
    /// answerable (ticket 03, failure shape 1). Every number comes from the
    /// dataset; none is hard-coded.
    static func beyondRangeDialog(
        now: Date,
        timeZone: TimeZone = nepalTimeZone,
        in dataset: CalendarDataset
    ) -> LocalizedStringResource {
        let gregorianToday = todayAD(now: now, timeZone: timeZone)
        let prefix = IntentAnswers.weekdayPrefix(gregorianToday.flatMap { weekday(of: $0) })
        let spokenToday = gregorianToday.map { IntentAnswers.spoken($0) } ?? ""
        // Years interpolate as strings: a bare Int formats with locale
        // grouping ("2,084"), which is wrong in a spoken year.
        return "NepalKit's Bikram Sambat data covers up to the year \(String(dataset.supportedRange.upperBound)). Today is \(prefix)\(spokenToday)."
    }
}
