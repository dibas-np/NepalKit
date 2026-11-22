// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Dibas Sigdel
import Foundation
import NepalKitCore

/// The menu-bar title, its spoken form, and the Menu Bar tab's format bindings.
extension MenuBarModel {
    /// The Bikram Sambat date with the parts `format` asks for, read in `timeZone`.
    /// Past the supported range the whole title becomes a compact boundary marker.
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

    /// What VoiceOver announces for the menu-bar extra: a full sentence, with the
    /// update marker spoken as words.
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

    // Binding targets for the Menu Bar tab; each write goes through `save(_:)`.

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
