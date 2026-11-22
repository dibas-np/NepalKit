// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Dibas Sigdel
import SwiftUI
import NepalKitCore

/// Today's festivals and holiday status, read once so the hero's line and its
/// announcement cannot disagree.
struct TodayObservances {
    let festivals: [Festival]
    let isPublicHoliday: Bool
    /// False when the gazette's own name ("Dashain holiday") already says it.
    let saysPublicHoliday: Bool

    init(_ day: BikramSambatDate, festivals: FestivalCalendar, holidays: PublicHolidayCalendar) {
        self.festivals = holidays.observances(on: day, festivals: festivals)
        self.isPublicHoliday = holidays.isNationwideHoliday(day)
        let namedOnlyByGazette = festivals.festivals(on: day).isEmpty && !self.festivals.isEmpty
        self.saysPublicHoliday = isPublicHoliday && !namedOnlyByGazette
    }

    func line(monthNames: MonthNameStyle) -> String? {
        guard !festivals.isEmpty || isPublicHoliday else { return nil }
        return Strings.todayFestivalLine(
            festivals.map { $0.name(style: monthNames) }, isPublicHoliday: saysPublicHoliday, monthNames: monthNames
        )
    }
}

/// Today's date as the hero, with the Gregorian line beneath it.
struct TodaySection: View {
    let clock: ClockModel
    let settings: DisplaySettings
    let dataset: CalendarDataset
    var festivals: FestivalCalendar = .panchanga
    var holidays: PublicHolidayCalendar = .gazette

    /// Named in the out-of-range state so a user can tell a data limit from a bug.
    private var lastSupportedBSYear: Int { dataset.supportedRange.upperBound }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // No "Today" heading: the selected tab already says it.

            if let todayBS = clock.todayBSDate(in: dataset) {
                // `largeTitle` rather than a point size so it follows the accessibility text size.
                // The weekday is a separate `Text` so a long one wraps without breaking the date.
                let observances = TodayObservances(todayBS, festivals: festivals, holidays: holidays)
                VStack(alignment: .leading, spacing: 2) {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(todayBS.formatted(settings))
                            .font(.largeTitle.bold())
                        if let weekday = clock.weekdayString(style: settings.monthNames) {
                            Text("\(Strings.weekdaySeparator) \(weekday)")
                                .font(.title3)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .fixedSize(horizontal: false, vertical: true)
                    // A holiday observed only in some places is left to the day's details.
                    if let line = observances.line(monthNames: settings.monthNames) {
                        Text(line)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                // The announcement adds the Gregorian date, which is otherwise shown only in the grid.
                .accessibilityElement(children: .combine)
                .accessibilityLabel(heroAnnouncement(todayBS, observances: observances))
            } else {
                // Past the supported range. The Gregorian date and clocks still answer, so this is
                // not styled as an error.
                VStack(alignment: .leading, spacing: 2) {
                    Text(Strings.bsDateUnavailable)
                        .font(.title3)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(Strings.supportedThrough(lastSupportedBSYear, digits: settings.digits))
                        .foregroundStyle(.secondary)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel(
                    "\(Strings.bsDateUnavailable). \(Strings.supportedThrough(lastSupportedBSYear, digits: .latin))"
                )
            }

            // In range, the grid already shows today's Gregorian date.
            if clock.todayBSDate(in: dataset) == nil, let todayAD = clock.todayADDate() {
                let weekday = clock.weekdayString(style: settings.monthNames)
                HStack(spacing: 4) {
                    Text(todayAD.formatted(digits: settings.digits))
                    if let weekday {
                        Text("\(Strings.weekdaySeparator) \(weekday)")
                    }
                }
                .font(.callout)
                .foregroundStyle(.secondary)
                .accessibilityElement(children: .combine)
                .accessibilityLabel(
                    SpokenDate.gregorianAnnouncement(date: todayAD, weekday: weekday)
                )
            }
        }
    }
}

extension TodaySection {
    fileprivate func heroAnnouncement(_ todayBS: BikramSambatDate, observances: TodayObservances) -> String {
        SpokenDate.today(
            todayBS, gregorian: clock.todayADDate(),
            weekday: clock.weekdayString(style: settings.monthNames), monthNames: settings.monthNames,
            festivals: observances.festivals, isPublicHoliday: observances.saysPublicHoliday
        )
    }
}
