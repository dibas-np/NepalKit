// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Dibas Sigdel
import AppKit

@MainActor
enum AppTermination {
    static func quit() {
        NSApplication.shared.terminate(nil)
    }
}
