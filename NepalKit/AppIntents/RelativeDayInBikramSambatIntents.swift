// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Dibas Sigdel
import AppIntents
import NepalKitCore

/// The Bikram Sambat date one Nepal Time civil day away from Today.
///
/// Civil-day arithmetic, never instant arithmetic: Today's Gregorian day in
/// Nepal Time, advanced by whole days, then converted. Adding 86,400 seconds
/// to `now` would agree on every day Nepal has today, but only by accident.
nonisolated enum RelativeDay {
    static func bsDay(offset: Int, now: Date, in dataset: CalendarDataset) -> BSDay? {
        guard let target = todayAD(now: now)?.advanced(byDays: offset) else { return nil }
        return adToBS(target, in: dataset)
    }

    /// The entity and the `<weekday>, <spoken date>` text for the day, or the
    /// range-boundary error Today uses once the day leaves the supported range.
    static func answer(
        offset: Int,
        now: Date,
        in dataset: CalendarDataset,
        monthNames: MonthNameStyle = SettingsStore().settings.monthNames
    ) throws -> (entity: BikramSambatDateEntity, spoken: String) {
        guard let bs = bsDay(offset: offset, now: now, in: dataset) else {
            throw SiriIntentError(dialog: TodayInBikramSambatIntent.beyondRangeDialog(now: now, in: dataset))
        }
        guard let entity = BikramSambatDateEntity(bsDay: bs, monthNames: monthNames) else {
            throw SiriIntentError(dialog: "NepalKit couldn't build that date.")
        }
        let prefix = IntentAnswers.weekdayPrefix(weekday(of: bs, in: dataset), monthNames: monthNames)
        return (entity, prefix + IntentAnswers.spoken(bs, monthNames: monthNames))
    }
}

/// The shared shape of the tomorrow and yesterday intents: each names only
/// its offset and its dialog.
nonisolated protocol RelativeDayIntent: AppIntent {
    static var offset: Int { get }
    static func dialog(_ spoken: String) -> LocalizedStringResource
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
        monthNames: MonthNameStyle = SettingsStore().settings.monthNames
    ) throws -> (entity: BikramSambatDateEntity, dialog: LocalizedStringResource) {
        let answer = try RelativeDay.answer(offset: offset, now: now, in: dataset, monthNames: monthNames)
        return (answer.entity, dialog(answer.spoken))
    }
}

/// Answers tomorrow's date in Bikram Sambat: the Nepal Time day after Today.
///
/// One parameterless intent per offset rather than one intent with an offset
/// parameter: voice only works for parameterless intents on macOS 26 (the
/// spec's surface table), and each App Shortcut binds one intent type.
struct TomorrowInBikramSambatIntent: RelativeDayIntent {
    static let title: LocalizedStringResource = "What is tomorrow's Bikram Sambat date"

    static var description: IntentDescription {
        IntentDescription("Speaks tomorrow's date in Bikram Sambat, Nepal's calendar.")
    }

    static let offset = 1

    static func dialog(_ spoken: String) -> LocalizedStringResource { "Tomorrow is \(spoken)." }
}

/// Answers yesterday's date in Bikram Sambat: the Nepal Time day before Today.
struct YesterdayInBikramSambatIntent: RelativeDayIntent {
    static let title: LocalizedStringResource = "What was yesterday's Bikram Sambat date"

    static var description: IntentDescription {
        IntentDescription("Speaks yesterday's date in Bikram Sambat, Nepal's calendar.")
    }

    static let offset = -1

    static func dialog(_ spoken: String) -> LocalizedStringResource { "Yesterday was \(spoken)." }
}
