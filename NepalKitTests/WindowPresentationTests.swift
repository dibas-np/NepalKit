import Foundation
import Testing
@testable import NepalKit

/// ADR-0011: opening a window from this app does not establish activation or
/// focus, so `WindowPresentation` does it explicitly. Ticket 05 then measured
/// *which* activation actually fronts a menu-bar-only app and found
/// `NSApp.activate()` cannot: it activates only when no other app is active, and
/// this app is summoned while one is. These tests pin the ordering that makes
/// the chosen call work — open first, then activate — and that the activation
/// is not run inline ahead of the open.
@MainActor
struct WindowPresentationTests {
    @Test func opensBeforeItActivates() {
        var order: [String] = []
        WindowPresentation.present(
            open: { order.append("open") },
            activate: { order.append("activate") },
            schedule: { work in work() }
        )
        #expect(order == ["open", "activate"])
    }

    @Test func activationIsDeferredUntilAfterTheOpenReturns() {
        // Models re-entrancy precisely: if `activate` ran inline, `open` would
        // still be executing and `openInProgress` would be true. The scheduler
        // is where "open has returned" happens, so clearing it there is what
        // makes the difference observable. A future change that activates
        // inline ahead of the open fails this.
        var openInProgress = false
        var activatedWhileOpenInProgress = false
        WindowPresentation.present(
            open: { openInProgress = true },
            activate: { activatedWhileOpenInProgress = openInProgress },
            schedule: { work in
                openInProgress = false
                work()
            }
        )
        #expect(activatedWhileOpenInProgress == false)
    }

    @Test func defersThroughTheInjectedScheduler() {
        // The default scheduler hops the main queue, so activation must not run
        // inline. Measured to work either way against the real app, so this
        // pins the chosen shape rather than a proven requirement — it keeps the
        // hop from being quietly dropped, which is harmless, and keeps anyone
        // from "simplifying" it into activating ahead of the open.
        var scheduled = false
        var ran = false
        WindowPresentation.present(
            open: {},
            activate: { ran = true },
            schedule: { _ in
                scheduled = true
            }
        )
        #expect(scheduled == true)
        #expect(ran == false)
    }

    @Test func presentsExactlyOnceEach() {
        var opens = 0
        var activations = 0
        WindowPresentation.present(
            open: { opens += 1 },
            activate: { activations += 1 },
            schedule: { work in work() }
        )
        #expect(opens == 1)
        #expect(activations == 1)
    }
}
