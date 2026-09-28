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
/// app — which is what the `ignoringOtherApps` option expresses.
///
/// `NSRunningApplication.activate(options:)` is the current API and takes that
/// option as a flag, which is preferable to the deprecated
/// `NSApplication` method whose old Swift spelling no longer compiles. The
/// *option* carries a soft deprecation of its own — Apple's message says
/// `ignoringOtherApps` "will have no effect" — but at macOS 27 it is
/// demonstrably the only thing that fronts this app, so it is used and the
/// risk is noted rather than papered over. If it ever stops working, Settings
/// opens without focus, which `WindowPresentationTests` and the real-app check
/// will both show immediately.
///
/// The activation is deferred by one main-queue hop. Measured both ways against
/// the real app — activating in the same turn and on the next turn both produce
/// an active app with a key Settings window — so the hop is a cheap safeguard
/// against SwiftUI creating the window asynchronously, not a requirement. What
/// *is* load-bearing is the ordering: never activate before opening, or the app
/// comes forward with no window to focus.
@MainActor
enum WindowPresentation {
    static func present(
        open: () -> Void,
        activate: @escaping () -> Void = {
            NSRunningApplication.current.activate(options: [.activateAllWindows, .activateIgnoringOtherApps])
        },
        schedule: (@escaping () -> Void) -> Void = { work in
            DispatchQueue.main.async(execute: work)
        }
    ) {
        open()
        schedule { activate() }
    }
}
