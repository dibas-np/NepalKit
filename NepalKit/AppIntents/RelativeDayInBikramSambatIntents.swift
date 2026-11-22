// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Dibas Sigdel
import AppIntents
import NepalKitCore

nonisolated enum RelativeDay {
    struct Answer {
        let entity: BikramSambatDateEntity
        let spoken: String
        let isProvisional: Bool
    }

    static func bsDay(offset: Int, now: Date, timeZone: TimeZone = .nepal, in dataset: CalendarDataset) -> BikramSambatDate? {
        guard let target = GregorianDate.today(now: now, timeZone: timeZone)?.advanced(byDays: offset) else { return nil }
        return BikramSambatDate(target, in: dataset)
    }

    static func answer(
        offset: Int,
        now: Date,
        in dataset: CalendarDataset,
        monthNames: MonthNameStyle = SettingsStore().settings.monthNames,
        timeZone: TimeZone = SettingsStore().timeReference.timeZone
    ) throws -> Answer {
        guard let bs = bsDay(offset: offset, now: now, timeZone: timeZone, in: dataset) else {
            throw SiriIntentError(dialog: TodayInBikramSambatIntent.beyondRangeDialog(now: now, timeZone: timeZone, in: dataset))
        }
        guard let entity = BikramSambatDateEntity(bsDay: bs, monthNames: monthNames) else {
            throw SiriIntentError(dialog: "NepalKit couldn't build that date.")
        }
        let prefix = IntentAnswers.weekdayPrefix(bs.weekday(in: dataset), monthNames: monthNames)
        return Answer(
            entity: entity,
            spoken: prefix + IntentAnswers.spoken(bs, monthNames: monthNames),
            isProvisional: dataset.isProvisional(bs.year)
        )
    }
}

nonisolated protocol RelativeDayIntent: AppIntent {
    static var offset: Int { get }
    static func dialog(_ spoken: String, isProvisional: Bool) -> LocalizedStringResource
}

nonisolated extension RelativeDayIntent {
    static var supportedModes: IntentModes { .background }

    func perform() async throws -> some IntentResult & ReturnsValue<BikramSambatDateEntity> & ProvidesDialog {
        let answer = try Self.answer(now: Date(), in: AppData.dataset)
        return .result(value: answer.entity, dialog: IntentDialog(answer.dialog))
    }

    static func answer(
        now: Date,
        in dataset: CalendarDataset,
        monthNames: MonthNameStyle = SettingsStore().settings.monthNames,
        timeZone: TimeZone = SettingsStore().timeReference.timeZone
    ) throws -> (entity: BikramSambatDateEntity, dialog: LocalizedStringResource) {
        let answer = try RelativeDay.answer(offset: offset, now: now, in: dataset, monthNames: monthNames, timeZone: timeZone)
        return (answer.entity, dialog(answer.spoken, isProvisional: answer.isProvisional))
    }
}

struct TomorrowInBikramSambatIntent: RelativeDayIntent {
    static let title: LocalizedStringResource = "What is tomorrow's Bikram Sambat date"

    static var description: IntentDescription {
        IntentDescription("Speaks tomorrow's date in Bikram Sambat, Nepal's calendar.")
    }

    static let offset = 1

    static func dialog(_ spoken: String, isProvisional: Bool) -> LocalizedStringResource {
        isProvisional
            ? "Tomorrow is \(spoken). That year is a provisional projection, not yet in the official Nepali Patro."
            : "Tomorrow is \(spoken)."
    }
}

struct YesterdayInBikramSambatIntent: RelativeDayIntent {
    static let title: LocalizedStringResource = "What was yesterday's Bikram Sambat date"

    static var description: IntentDescription {
        IntentDescription("Speaks yesterday's date in Bikram Sambat, Nepal's calendar.")
    }

    static let offset = -1

    static func dialog(_ spoken: String, isProvisional: Bool) -> LocalizedStringResource {
        isProvisional
            ? "Yesterday was \(spoken). That year is a provisional projection, not yet in the official Nepali Patro."
            : "Yesterday was \(spoken)."
    }
}
