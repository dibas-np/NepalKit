// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Dibas Sigdel
import AppIntents
import NepalKitCore

nonisolated enum RelativeDay: String, AppEnum {
    case tomorrow
    case yesterday

    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Day"

    static let caseDisplayRepresentations: [RelativeDay: DisplayRepresentation] = [
        .tomorrow: "Tomorrow",
        .yesterday: "Yesterday",
    ]

    var offset: Int {
        switch self {
        case .tomorrow: 1
        case .yesterday: -1
        }
    }

    struct Answer {
        let entity: BikramSambatDateEntity
        let spoken: String
        let isProvisional: Bool
    }

    static func bsDay(offset: Int, now: Date, timeZone: TimeZone = .nepal, in dataset: CalendarDataset) -> BikramSambatDate? {
        guard let target = GregorianDate.today(now: now, timeZone: timeZone)?.advanced(byDays: offset) else { return nil }
        return BikramSambatDate(target, in: dataset)
    }

    func answer(
        now: Date,
        in dataset: CalendarDataset,
        monthNames: MonthNameStyle = SettingsStore().settings.monthNames,
        timeZone: TimeZone = SettingsStore().timeReference.timeZone
    ) throws -> Answer {
        guard let bs = Self.bsDay(offset: offset, now: now, timeZone: timeZone, in: dataset) else {
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

struct RelativeDayInBikramSambatIntent: AppIntent {
    static let title: LocalizedStringResource = "Tomorrow's or yesterday's Bikram Sambat date"

    static var description: IntentDescription {
        IntentDescription("Speaks tomorrow's or yesterday's date in Bikram Sambat, Nepal's calendar.")
    }

    static let supportedModes: IntentModes = .background

    @Parameter(title: "Day", default: .tomorrow)
    var day: RelativeDay

    static var parameterSummary: some ParameterSummary {
        Summary("\(\.$day)'s Bikram Sambat date")
    }

    init() {}

    init(day: RelativeDay) {
        self.day = day
    }

    func perform() async throws -> some IntentResult & ReturnsValue<BikramSambatDateEntity> & ProvidesDialog {
        let answer = try Self.answer(day, now: Date(), in: AppData.dataset)
        return .result(value: answer.entity, dialog: IntentDialog(answer.dialog))
    }

    static func answer(
        _ day: RelativeDay,
        now: Date,
        in dataset: CalendarDataset,
        monthNames: MonthNameStyle = SettingsStore().settings.monthNames,
        timeZone: TimeZone = SettingsStore().timeReference.timeZone
    ) throws -> (entity: BikramSambatDateEntity, dialog: LocalizedStringResource) {
        let answer = try day.answer(now: now, in: dataset, monthNames: monthNames, timeZone: timeZone)
        return (answer.entity, dialog(day, answer.spoken, isProvisional: answer.isProvisional))
    }

    static func dialog(_ day: RelativeDay, _ spoken: String, isProvisional: Bool) -> LocalizedStringResource {
        switch (day, isProvisional) {
        case (.tomorrow, true):
            "Tomorrow is \(spoken). That year is a provisional projection, not yet in the official Nepali Patro."
        case (.tomorrow, false):
            "Tomorrow is \(spoken)."
        case (.yesterday, true):
            "Yesterday was \(spoken). That year is a provisional projection, not yet in the official Nepali Patro."
        case (.yesterday, false):
            "Yesterday was \(spoken)."
        }
    }
}
