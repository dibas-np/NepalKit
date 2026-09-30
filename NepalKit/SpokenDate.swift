// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Dibas Sigdel
import NepalKitCore

/// The app-side half of the spoken forms: everything that composes app copy.
/// The copy-free transformations live in NepalKitCore, where the boundary rule
/// puts them and where any consumer of the package can reach them.
extension SpokenDate {
    /// A full announcement for the menu-bar extra.
    ///
    /// The hardest surface in the app, and the ticket's most visible one: it is
    /// the only thing a blind user meets before opening anything. A bare date
    /// like "11 Ashoj" says nothing about *which* app it belongs to, and someone
    /// navigating by menu-bar extras is relying on this one string entirely.
    /// Naming the app costs a word and makes the item identifiable out of
    /// context.
    ///
    /// - Parameter updateAvailable: adds the reminder clause. It goes *after* the
    ///   app name and *before* the date, because nothing may precede the name —
    ///   that is what makes the item identifiable — and the reminder is the part
    ///   that asks the user to act.
    static func menuBar(
        today: BSDay?,
        monthNames: MonthNameStyle,
        dataset: CalendarDataset,
        updateAvailable: Bool = false
    ) -> String {
        let reminder = updateAvailable ? "\(Strings.updateAvailableSpoken), " : ""
        guard let today else {
            // Past the supported range the label is a marker, not a date, and a
            // bare "n/a" spoken alone is meaningless — it reads as a broken
            // item. Say what actually happened instead. The end date comes from
            // the dataset itself, so a table change moves this sentence with it
            // (ADR-0010: no range literal outside the dataset).
            guard let end = dataset.gregorianEnd else {
                return "\(Strings.appNameForSpeech), \(reminder)\(Strings.bsDateUnavailable)"
            }
            return "\(Strings.appNameForSpeech), \(reminder)\(Strings.spokenDateBeyondRange(ad(end)))"
        }
        return "\(Strings.appNameForSpeech), \(reminder)\(bs(today, monthNames: monthNames))"
    }
}
