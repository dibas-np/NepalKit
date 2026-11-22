// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Dibas Sigdel
import NepalKitCore

/// App-side spoken forms; the copy-free transformations live in NepalKitCore.
extension SpokenDate {
    /// The menu-bar extra's announcement. It always starts with the app name so
    /// the item is identifiable out of context; an update reminder follows it.
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

    /// The same announcement around an already-spoken date. Nil means the date
    /// is past the supported range.
    static func menuBar(
        spokenDate: String?,
        dataset: CalendarDataset,
        updateAvailable: Bool = false
    ) -> String {
        let reminder = updateAvailable ? "\(Strings.updateAvailableSpoken), " : ""
        guard let spokenDate else {
            // Past the range, say why rather than reading out "n/a".
            guard let end = dataset.gregorianEnd else {
                return "\(Strings.appNameForSpeech), \(reminder)\(Strings.bsDateUnavailable)"
            }
            return "\(Strings.appNameForSpeech), \(reminder)\(Strings.spokenDateBeyondRange(gregorian(end)))"
        }
        return "\(Strings.appNameForSpeech), \(reminder)\(spokenDate)"
    }

    /// A Gregorian date with its weekday, if the weekday lookup succeeded.
    static func gregorianAnnouncement(date: GregorianDate, weekday: String?) -> String {
        guard let weekday else { return gregorian(date) }
        return "\(gregorian(date)), \(weekday)"
    }
}
