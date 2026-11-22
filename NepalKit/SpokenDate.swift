// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Dibas Sigdel
import NepalKitCore

extension SpokenDate {
    static func menuBar(
        today: BikramSambatDate?,
        monthNames: MonthNameStyle,
        dataset: CalendarDataset,
        updateAvailable: Bool = false
    ) -> String {
        menuBar(
            spokenDate: today.map { bikramSambat($0, monthNames: monthNames) },
            dataset: dataset,
            updateAvailable: updateAvailable
        )
    }

    static func menuBar(
        spokenDate: String?,
        dataset: CalendarDataset,
        updateAvailable: Bool = false
    ) -> String {
        let reminder = updateAvailable ? "\(Strings.updateAvailableSpoken), " : ""
        guard let spokenDate else {
            guard let end = dataset.gregorianEnd else {
                return "\(Strings.appNameForSpeech), \(reminder)\(Strings.bsDateUnavailable)"
            }
            return "\(Strings.appNameForSpeech), \(reminder)\(Strings.spokenDateBeyondRange(gregorian(end)))"
        }
        return "\(Strings.appNameForSpeech), \(reminder)\(spokenDate)"
    }

    static func gregorianAnnouncement(date: GregorianDate, weekday: String?) -> String {
        guard let weekday else { return gregorian(date) }
        return "\(gregorian(date)), \(weekday)"
    }
}
