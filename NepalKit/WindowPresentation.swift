// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Dibas Sigdel
import AppKit

/// Establishes activation and focus when a command opens a normal application
/// window from NepalKit's menu-bar-only context.
///
/// ADR-0011 measured the gap this closes: opening such a window puts it on
/// screen but leaves `NSApp.keyWindow` nil, `NSApp.isActive` false, and another
/// application still frontmost. The window is focusable, just not focused — so
/// it opens and cannot be used. Every command that opens a window goes through
/// here rather than each growing its own activation call, so About (ticket 06)
/// inherits the behaviour instead of reimplementing it.
///
/// **Why `NSRunningApplication` and not `NSApp.activate()`.** Measured against
/// the real app bundle, five strategies, each after resetting the active app so
/// none could inherit the previous one's success:
///
/// | Strategy | App active | Settings window key |
/// | --- | --- | --- |
/// | `NSApp.activate()` | no | no |
/// | `NSRunningApplication…activate(options: [])` | no | no |
/// | `NSRunningApplication…activate(options: [.activateAllWindows])` | no | no |
/// | `NSRunningApplication…activate(options: [.activateAllWindows, .activateIgnoringOtherApps])` | **yes** | **yes** |
/// | `NSApp.activate(ignoringOtherApps: true)` | **yes** | **yes** |
///
/// `NSApp.activate()` cannot work here: it activates only when no other
/// application is active, and a menu-bar app is being summoned *while* one is.
/// So the activation must be able to come forward over the current frontmost
/// app — which is what the `ignoringOtherApps` flag expresses.
///
/// **Which spelling, and why the obvious answer is not the one used.** The
/// current API is `NSRunningApplication.activate(options:)`, and it takes the
/// same behaviour as a flag — but that flag is deprecated, and Apple's own
/// message says it "will have no effect". The table above already recorded
/// that the older `NSApp.activate(ignoringOtherApps: true)` fronts this app
/// just as reliably, and that spelling is *not* deprecated. It is therefore
/// what is used: the measured behaviour is preserved and the warning is gone,
/// rather than a deprecated call being kept alive under a documented risk.
///
/// **`isActive` is the retry condition, not the request's return value.** The
/// older API returned a `Bool` saying whether the request was accepted, which
/// is a proxy for the thing that actually matters. `NSApp.isActive` reports
/// whether the app came forward, so the bounded retry now continues for
/// exactly as long as the app is not yet frontmost — which is the real
/// condition, and stricter than trusting a submission receipt.
///
/// The activation is attempted on a later main-queue turn, and retried a bounded
/// number of times *only while the activation request is refused*.
///
/// Retry rather than a longer sleep, because the observed failure is a refused
/// request, not a mistimed one: `activate(options:)` returns `false` and the app
/// never comes forward, leaving the window open and dead to the keyboard. A
/// fixed delay would paper over that and still fail when the machine is busy.
///
/// Measured for the `Settings` scene: activating in the same turn and on the
/// next turn both work. Measured for a lazily created `Window` scene (About):
/// the same one-turn hop worked on some launches and not others, which is why
/// this is bounded-retry rather than a magic interval. Either way the invariant
/// that matters is unchanged — never activate before opening, and never give up
/// while the user is still waiting for a usable window.
@MainActor
enum WindowPresentation {
    static func present(
        open: () -> Void,
        // @MainActor on the closure, not just on the enum: a default argument
        // expression is evaluated in a nonisolated context even when the
        // enclosing function is isolated, so a body touching NSApp warns
        // without it. The same reason the model initialisers below moved their
        // defaults out of the signature.
        activate: @escaping @MainActor () -> Bool = {
            NSApp.activate(ignoringOtherApps: true)
            return NSApp.isActive
        },
        attempts: Int = 3,
        schedule: @escaping (@escaping @MainActor @Sendable () -> Void) -> Void = { work in
            DispatchQueue.main.async(execute: work)
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
