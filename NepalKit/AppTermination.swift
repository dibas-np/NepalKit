import AppKit

/// The app's single exit path.
///
/// Both the popover's Quit button and the ⌘Q command call this, so there is one
/// place to change if termination ever needs to do more than stop the process.
/// A menu-bar-only app has no Dock icon and no Cmd-Tab presence, so this is the
/// only normal way out.
@MainActor
enum AppTermination {
    static func quit() {
        NSApplication.shared.terminate(nil)
    }
}
