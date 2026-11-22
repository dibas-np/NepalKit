// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Dibas Sigdel
import Foundation

enum Symbols {
    static let launchAtLogin = "power"

    static let settings = "gearshape"

    static let about = "info.circle"

    static let menuBar = "menubar.rectangle"

    static let general = "slider.horizontal.3"

    static let repository = "chevron.left.forwardslash.chevron.right"

    static let update = "arrow.down.circle"

    static let previousMonth = "chevron.left"
    static let nextMonth = "chevron.right"

    static let closeDetails = "xmark.circle.fill"

    static let all: [String] = [
        launchAtLogin, settings, about, menuBar, general, repository, update,
        previousMonth, nextMonth, closeDetails
    ]
}
