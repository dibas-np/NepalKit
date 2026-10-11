// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Dibas Sigdel
import SwiftUI
import NepalKitCore

/// What today is besides a date: its festivals, and whether it is a
/// nationwide public holiday. Read once so the hero's line and its
/// announcement come from the same lookup and cannot disagree.
struct TodayObservances {
    let festivals: [Festival]
    let isPublicHoliday: Bool

    init(_ day: BSDay, festivals: FestivalCalendar, holidays: PublicHolidayCalendar) {
        self.festivals = festivals.festivals(on: day)
        self.isPublicHoliday = holidays.isNationwideHoliday(day)
    }

    /// The line under the hero, or nil on a day with nothing to say: an empty
    /// line on every other day would be space spent saying nothing.
    func line(monthNames: MonthNameStyle) -> String? {
        guard !festivals.isEmpty || isPublicHoliday else { return nil }
        return Strings.todayFestivalLine(
            festivals.map { $0.name(style: monthNames) }, isPublicHoliday: isPublicHoliday, monthNames: monthNames
        )
    }
}

/// Today's date as the hero, with the Gregorian line beneath it.
struct TodaySection: View {
    let clock: ClockModel
    let settings: DisplaySettings
    let dataset: CalendarDataset
    /// Today's festivals come from here; the month grid marks the same table.
    var festivals: FestivalCalendar = .panchanga
    /// And today's public holiday, from the table that turns the grid's day red.
    var holidays: PublicHolidayCalendar = .gazette

    /// Last Bikram Sambat year the bundled dataset can convert. Named in the
    /// range boundary state so a user past it can tell a data limit from a bug.
    private var lastSupportedBSYear: Int { dataset.supportedRange.upperBound }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // No "Today" header here. The segmented control directly above already
            // reads "Today" and is the selected segment, so a second "Today" two
            // lines down repeats the destination to confirm what the control just
            // said. Removing it also lets the date sit at the top of the content
            // rather than below a label describing it.
            //
            // The heading role is not lost: the segmented control carries the
            // destination name, and the date below it is the first thing a reader
            // meets either way.

            if let todayBS = clock.todayBSDate(in: dataset) {
                // The hero. Weight is what makes the date the first thing read
                // rather than a value sitting beside its own label; everything
                // below steps down from it.
                //
                // `largeTitle`, and semantic like every other font here. This was
                // a literal `system(size: 28)` — 2pt larger, and not scaling: a
                // literal point size ignores the system accessibility text size,
                // so a user enlarging text saw every line grow except the hero.
                //
                // Shown exactly as configured; announced in a form a voice can
                // pronounce. The two come from the same date, so they cannot
                // drift into describing different days.
                //
                // The weekday sits beside the date, a step down, so the day of
                // the week is read with the date instead of hunted for in the
                // grid's header. Two `Text`s, like the Gregorian line below, so
                // a long weekday wraps on its own rather than breaking the date;
                // one `Text` at the hero's size did not fit "Wednesday" on the
                // row.
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
                    // Today's festivals and national days, a step below the
                    // date. A nationwide public holiday says so at the end,
                    // because that is what a reader opening the app on one
                    // wants to know; a limited one waits for the day's details.
                    if let line = observances.line(monthNames: settings.monthNames) {
                        Text(line)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                // Combined so the hero is one element, and relabelled: the
                // Gregorian date is no longer a line of its own (the grid shows
                // it under today), so the announcement carries it - one
                // sentence with both calendars and the weekday, which it
                // already names, so the shown weekday is not said twice - and
                // then today's festivals.
                .accessibilityElement(children: .combine)
                .accessibilityLabel(heroAnnouncement(todayBS, observances: observances))
            } else {
                // Range boundary state: the bundled data has ended. Say so in
                // words rather than showing a blank, and keep the Gregorian date
                // and clocks below, which are still answerable.
                // One element, not two: a heading and a sub-line are two
                // separate announcements, and the second alone ("Supported
                // through 2084 BS") is meaningless without the first. Merged, and
                // given a single label, so the whole state is one sentence.
                //
                // Not styled as an error. The dataset ended, the app did not
                // fail, and an alert-coloured panel would imply the user has done
                // something wrong. The same weight as the date it replaces keeps
                // the layout from jumping when the range is crossed.
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
                // One date, two channels: the shown line as configured, the
                // announcement with Latin digits and the weekday folded in, so
                // the whole line is a single spoken sentence.
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
            festivals: observances.festivals, isPublicHoliday: observances.isPublicHoliday
        )
    }
}
