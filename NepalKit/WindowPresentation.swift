// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Dibas Sigdel
import AppKit

/// `NSApp.activate()` won't come forward while another app is active,
/// so this uses the soft-deprecated `activate(ignoringOtherApps:)` and retries a
/// bounded number of times until `NSApp.isActive`.
@MainActor
enum WindowPresentation {
    static func present(
        open: () -> Void,
        activate: @escaping @MainActor () -> Bool = {
            NSApp.activate(ignoringOtherApps: true)
            return NSApp.isActive
        },
        attempts: Int = 3,
        schedule: @escaping (@escaping @MainActor @Sendable () -> Void) -> Void = { work in
            Task { @MainActor in work() }
        }
    ) {
        open()
        attemptActivation(activate, remaining: attempts, schedule: schedule)
    }

    private static func attemptActivation(
        _ activate: @escaping @MainActor () -> Bool,
        remaining: Int,
        schedule: @escaping (@escaping @MainActor @Sendable () -> Void) -> Void
    ) {
        guard remaining > 0 else { return }
        schedule {
            guard !activate() else { return }
            attemptActivation(activate, remaining: remaining - 1, schedule: schedule)
        }
    }
}
