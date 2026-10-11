// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Dibas Sigdel
import AppIntents
import NepalKitCore

/// The Bikram Sambat date one civil day away from Today, in the zone the user's
/// time reference names (ADR-0017).
///
/// Civil-day arithmetic, never instant arithmetic: Today's Gregorian day in
/// that zone, advanced by whole days, then converted. Adding 86,400 seconds
/// to `now` would agree on every day Nepal has today, but only by accident,
/// and not on a daylight-saving change in the user's own zone.
nonisolated enum RelativeDay {
    /// A relative day's answer: the entity, the `<weekday>, <spoken date>`
    /// text, and whether the day's year is a provisional projection.
    struct Answer {
        let entity: BikramSambatDateEntity
        let spoken: String
        let isProvisional: Bool
    }

    static func bsDay(offset: Int, now: Date, timeZone: TimeZone = nepalTimeZone, in dataset: CalendarDataset) -> BSDay? {
        guard let target = todayAD(now: now, timeZone: timeZone)?.advanced(byDays: offset) else { return nil }
        return adToBS(target, in: dataset)
    }

    /// The day's answer, or the range-boundary error Today uses once the day
    /// leaves the supported range.
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
        let prefix = IntentAnswers.weekdayPrefix(weekday(of: bs, in: dataset), monthNames: monthNames)
        return Answer(
            entity: entity,
            spoken: prefix + IntentAnswers.spoken(bs, monthNames: monthNames),
            isProvisional: dataset.isProvisional(bs.year)
        )
    }
}

/// The shared shape of the tomorrow and yesterday intents: each names only
/// its offset and its dialog.
nonisolated protocol RelativeDayIntent: AppIntent {
    static var offset: Int { get }
    /// The answer, with the provisional-year clause Today and the converters
    /// carry when the day falls in a projected year. Two literals rather than
    /// one interpolated clause, so each stays a localizable whole sentence.
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

/// Answers tomorrow's date in Bikram Sambat: the day after Today.
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

    static func dialog(_ spoken: String, isProvisional: Bool) -> LocalizedStringResource {
        isProvisional
            ? "Tomorrow is \(spoken). That year is a provisional projection, not yet in the official Nepali Patro."
            : "Tomorrow is \(spoken)."
    }
}

/// Answers yesterday's date in Bikram Sambat: the day before Today.
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
