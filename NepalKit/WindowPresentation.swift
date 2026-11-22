// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Dibas Sigdel
import AppKit

/// Activates the app and focuses a window opened from the menu-bar-only context.
/// Without this the window opens but the app stays behind the frontmost one
/// (ADR-0011). `NSApp.activate()` won't come forward while another app is active,
/// so this uses the soft-deprecated `activate(ignoringOtherApps:)` and retries a
/// bounded number of times until `NSApp.isActive`.
@MainActor
enum WindowPresentation {
    static func present(
        open: () -> Void,
        // @MainActor on the closure: a default argument is evaluated in a nonisolated
        // context even when the enclosing function is isolated.
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
