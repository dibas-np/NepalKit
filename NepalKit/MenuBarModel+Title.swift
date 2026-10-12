// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Dibas Sigdel
import Foundation
import NepalKitCore

/// What the menu-bar extra shows and says, and the Menu Bar tab's binding
/// targets for the format. Split from `MenuBarModel.swift`, which keeps the
/// clock and its timers.
extension MenuBarModel {
    /// The menu-bar title: the Bikram Sambat date, with the weekday, year and
    /// clock that `format` asks for, all read in `timeZone`, honoring the display settings.
    ///
    /// Past the dataset's supported range this returns a compact boundary marker
    /// rather than a bare "—". That marker is a statement of fact, not a warning:
    /// the menu bar has no room to explain itself, so its job is only to stop the
    /// absence reading as a bug; the popover is where the boundary is stated in
    /// words. It replaces the whole title, time included, so the marker means
    /// the same thing whatever the format.
    ///
    /// - Parameter updateAvailable: prefixes a warning marker, which is a
    ///   different thing from the boundary marker above — this one asks the user
    ///   to do something. The date is kept rather than replaced, because showing
    ///   today's date is the reason the item is in the menu bar at all, and an
    ///   update alert raised by a windowless app is easy to never notice.
    func title(
        settings: DisplaySettings,
        in dataset: CalendarDataset = AppData.dataset,
        updateAvailable: Bool = false
    ) -> String {
        guard let date = formatMenuBarTitle(now: now, timeZone: timeZone, format: format, settings: settings, in: dataset) else {
            return Strings.menuBarBeyondRange
        }
        return updateAvailable ? Strings.menuBarUpdateMarker + date : date
    }

    /// What VoiceOver announces for the menu-bar extra.
    ///
    /// Separate from `title` because the two answer different questions. The
    /// title is the menu bar's few pixels of space and carries the bare date; the
    /// announcement is a sentence, so it can name the app and say the date in a
    /// form a voice can actually pronounce. Splitting them is what keeps the
    /// menu bar from being made worse for everybody in order to help someone
    /// using speech — the visual stays exactly as short as it was.
    ///
    /// The update is announced as words rather than as the marker glyph, for the
    /// same reason the date is: a voice cannot read "!", and the marker is the
    /// one thing on this surface that changes what the user should do.
    func spokenTitle(
        settings: DisplaySettings,
        in dataset: CalendarDataset = AppData.dataset,
        updateAvailable: Bool = false
    ) -> String {
        SpokenDate.menuBar(
            spokenDate: SpokenDate.menuBarDate(now: now, timeZone: timeZone, format: format, monthNames: settings.monthNames, in: dataset),
            dataset: dataset,
            updateAvailable: updateAvailable
        )
    }

    // Binding targets for the Menu Bar tab's toggles: each write runs `save`,
    // so persistence, the label and the time tick move together.

    var showsWeekday: Bool {
        get { format.showsWeekday }
        set { saveFormat { $0.showsWeekday = newValue } }
    }

    var showsYear: Bool {
        get { format.showsYear }
        set { saveFormat { $0.showsYear = newValue } }
    }

    var showsTime: Bool {
        get { format.showsTime }
        set { saveFormat { $0.showsTime = newValue } }
    }

    var usesTwentyFourHourClock: Bool {
        get { format.usesTwentyFourHourClock }
        set { saveFormat { $0.usesTwentyFourHourClock = newValue } }
    }

    var showsSeconds: Bool {
        get { format.showsSeconds }
        set { saveFormat { $0.showsSeconds = newValue } }
    }

    private func saveFormat(_ change: (inout MenuBarFormat) -> Void) {
        var changed = format
        change(&changed)
        save(changed)
    }
}
