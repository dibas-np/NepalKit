// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Dibas Sigdel
import AppIntents
import NepalKitCore

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

    static func answer(
        now: Date,
        in dataset: CalendarDataset,
        timeZone: TimeZone = SettingsStore().timeReference.timeZone
    ) throws -> (entity: BikramSambatDateEntity, dialog: LocalizedStringResource) {
        guard let bs = BikramSambatDate.today(now: now, timeZone: timeZone, in: dataset) else {
            throw SiriIntentError(dialog: beyondRangeDialog(now: now, timeZone: timeZone, in: dataset))
        }
        guard let entity = BikramSambatDateEntity(bsDay: bs) else {
            throw SiriIntentError(dialog: "NepalKit couldn't build that date.")
        }
        return (entity, successDialog(bs, weekday: bs.weekday(in: dataset), in: dataset))
    }

    static func successDialog(_ bs: BikramSambatDate, weekday: Int?, in dataset: CalendarDataset) -> LocalizedStringResource {
        if dataset.isProvisional(bs.year) {
            return "Today is \(IntentAnswers.weekdayPrefix(weekday))\(IntentAnswers.spoken(bs)). This year is a provisional projection, not yet in the official Nepali Patro."
        }
        return "Today is \(IntentAnswers.weekdayPrefix(weekday))\(IntentAnswers.spoken(bs))."
    }

    static func beyondRangeDialog(
        now: Date,
        timeZone: TimeZone = .nepal,
        in dataset: CalendarDataset
    ) -> LocalizedStringResource {
        let gregorianToday = GregorianDate.today(now: now, timeZone: timeZone)
        let prefix = IntentAnswers.weekdayPrefix(gregorianToday.flatMap { $0.weekday })
        let spokenToday = gregorianToday.map { IntentAnswers.spoken($0) } ?? ""
        return "NepalKit's Bikram Sambat data covers up to the year \(IntentAnswers.number(dataset.supportedRange.upperBound)). Today is \(prefix)\(spokenToday)."
    }
}
