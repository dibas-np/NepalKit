// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Dibas Sigdel
import Foundation
import NepalKitCore

extension MenuBarModel {
    func title(
        settings: DisplaySettings,
        in dataset: CalendarDataset = AppData.dataset,
        updateAvailable: Bool = false
    ) -> String {
        let text = formatMenuBarTitle(now: now, timeZone: timeZone, format: format, settings: settings, in: dataset)
            ?? Strings.menuBarBeyondRange
        return updateAvailable ? Strings.menuBarUpdateMarker + text : text
    }

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
