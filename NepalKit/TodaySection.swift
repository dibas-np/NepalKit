// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Dibas Sigdel
import SwiftUI
import NepalKitCore

/// Today's festivals and whether it is a nationwide public holiday, read once
/// so the hero's line and its announcement cannot disagree.
struct TodayObservances {
    let festivals: [Festival]
    let isPublicHoliday: Bool
    /// Whether the line adds "Public holiday": not when the gazette's own name
    /// ("Dashain holiday") is the only one, which already says it.
    let saysPublicHoliday: Bool

    init(_ day: BSDay, festivals: FestivalCalendar, holidays: PublicHolidayCalendar) {
        self.festivals = holidays.observances(on: day, festivals: festivals)
        self.isPublicHoliday = holidays.isNationwideHoliday(day)
        let namedOnlyByGazette = festivals.festivals(on: day).isEmpty && !self.festivals.isEmpty
        self.saysPublicHoliday = isPublicHoliday && !namedOnlyByGazette
    }

    /// The line under the hero, or nil on a day with nothing to say.
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
    /// The same tables the month grid marks.
    var festivals: FestivalCalendar = .panchanga
    var holidays: PublicHolidayCalendar = .gazette

    /// Last Bikram Sambat year the bundled dataset can convert. Named in the
    /// range boundary state so a user past it can tell a data limit from a bug.
    private var lastSupportedBSYear: Int { dataset.supportedRange.upperBound }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // No "Today" header: the selected tab above already says it, and
            // the date belongs at the top. Nothing here is a heading.

            if let todayBS = clock.todayBSDate(in: dataset) {
                // The hero; everything below steps down from it. `largeTitle`,
                // not a literal point size, which ignores the accessibility
                // text size.
                //
                // The weekday is a separate `Text` so a long one wraps on its
                // own rather than breaking the date.
                let observances = TodayObservances(todayBS, festivals: festivals, holidays: holidays)
                VStack(alignment: .leading, spacing: 2) {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(formatBS(todayBS, settings: settings))
                            .font(.largeTitle.weight(.semibold))
                        if let weekday = clock.weekdayString(style: settings.monthNames) {
                            Text("\(Strings.weekdaySeparator) \(weekday)")
                                .font(.title3)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .fixedSize(horizontal: false, vertical: true)
                    // Today's festivals and national days, then any nationwide
                    // public holiday; a limited one waits for the day's details.
                    if let line = observances.line(monthNames: settings.monthNames) {
                        Text(line)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                // One element whose label adds the Gregorian date, which is
                // shown only in the grid: both calendars, the weekday once,
                // then today's festivals.
                .accessibilityElement(children: .combine)
                .accessibilityLabel(heroAnnouncement(todayBS, observances: observances))
            } else {
                // Range boundary state: the data has ended; the Gregorian date
                // and clocks below still answer. One element, as "Supported
                // through 2084 BS" alone means nothing. Not styled as an error:
                // the app did not fail.
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

            // Only past the supported range: the grid below shows today's
            // Gregorian day and month, so in range this line repeated it.
            if clock.todayBSDate(in: dataset) == nil, let todayAD = clock.todayADDate() {
                // Announced as one sentence, with Latin digits and the weekday.
                let weekday = clock.weekdayString(style: settings.monthNames)
                HStack(spacing: 4) {
                    Text(formatAD(todayAD, settings: settings))
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
    fileprivate func heroAnnouncement(_ todayBS: BSDay, observances: TodayObservances) -> String {
        SpokenDate.today(
            todayBS, gregorian: clock.todayADDate(),
            weekday: clock.weekdayString(style: settings.monthNames), monthNames: settings.monthNames,
            festivals: observances.festivals, isPublicHoliday: observances.saysPublicHoliday
        )
    }
}
