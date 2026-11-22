// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Dibas Sigdel
import AppKit

/// The app's single exit path, shared by the popover's Quit button and ⌘Q.
@MainActor
enum AppTermination {
    static func quit() {
        NSApplication.shared.terminate(nil)
    }
}
