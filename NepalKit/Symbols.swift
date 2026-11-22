// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Dibas Sigdel
import Foundation

/// Every SF Symbol the app uses, named once.
/// `SymbolTests` resolves every name in `all`, so a typo fails the suite instead
/// of rendering nothing. Inline icons are monochrome.
enum Symbols {
    static let launchAtLogin = "power"

    static let settings = "gearshape"

    static let about = "info.circle"

    /// The menu-bar settings tab.
    static let menuBar = "menubar.rectangle"

    /// Not `gearshape`, which is already the popover's Settings button.
    static let general = "slider.horizontal.3"

    /// The Source link in the Settings window's identity strip.
    static let repository = "chevron.left.forwardslash.chevron.right"

    /// The popover footer's update button.
    static let update = "arrow.down.circle"

    /// Month grid navigation; the buttons keep their titles for VoiceOver.
    static let previousMonth = "chevron.left"
    static let nextMonth = "chevron.right"

    /// Closes the day details under the month grid.
    static let closeDetails = "xmark.circle.fill"

    static let all: [String] = [
        launchAtLogin, settings, about, menuBar, general, repository, update,
        previousMonth, nextMonth, closeDetails
    ]
}
