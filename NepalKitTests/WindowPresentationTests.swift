import Foundation
import Testing
@testable import NepalKit

/// ADR-0011: opening a window from this app does not establish activation or
/// focus, so `WindowPresentation` does it explicitly. Ticket 05 measured *which*
/// activation actually fronts a menu-bar-only app and found `NSApp.activate()`
/// cannot: it activates only when no other app is active, and this app is
/// summoned while one is. Ticket 06 then found the activation request itself is
/// occasionally refused, which is why this retries rather than sleeping.
///
/// These pin the two invariants that carry the weight: activation never runs
/// ahead of the open, and a refused request is retried but bounded.
@MainActor
struct WindowPresentationTests {
    @Test func opensBeforeItActivates() {
        var order: [String] = []
        WindowPresentation.present(
            open: { order.append("open") },
            activate: { order.append("activate"); return true },
            schedule: { work in work() }
        )
        #expect(order == ["open", "activate"])
    }

    @Test func activationIsDeferredUntilAfterTheOpenReturns() {
        // Models re-entrancy precisely: if `activate` ran inline, `open` would
        // still be executing and `openInProgress` would be true. The scheduler
        // is where "open has returned" happens, so clearing it there is what
        // makes the difference observable.
        var openInProgress = false
        var activatedWhileOpenInProgress = false
        WindowPresentation.present(
            open: { openInProgress = true },
            activate: { activatedWhileOpenInProgress = openInProgress; return true },
            schedule: { work in
                openInProgress = false
                work()
            }
        )
        #expect(activatedWhileOpenInProgress == false)
    }

    @Test func defersThroughTheInjectedScheduler() {
        var scheduled = false
        var ran = false
        WindowPresentation.present(
            open: {},
            activate: { ran = true; return true },
            schedule: { _ in scheduled = true }
        )
        #expect(scheduled == true)
        #expect(ran == false)
    }

    @Test func stopsRetryingOnceActivationSucceeds() {
        // The common case must cost exactly one activation, not `attempts` of
        // them. Retrying after success would yank focus repeatedly.
        var activations = 0
        WindowPresentation.present(
            open: {},
            activate: { activations += 1; return true },
            attempts: 5,
            schedule: { work in work() }
        )
        #expect(activations == 1)
    }

    @Test func retriesWhileTheRequestIsRefused() {
        // A refused request is the observed failure: the app never comes
        // forward and the window is left open and dead. It must be retried.
        var activations = 0
        WindowPresentation.present(
            open: {},
            activate: {
                activations += 1
                return activations > 1
            },
            attempts: 5,
            schedule: { work in work() }
        )
        #expect(activations == 2)
    }

    @Test func retryIsBounded() {
        // Never retrying forever: a user who has walked away should not leave
        // the app fighting for focus indefinitely.
        var activations = 0
        WindowPresentation.present(
            open: {},
            activate: { activations += 1; return false },
            attempts: 3,
            schedule: { work in work() }
        )
        #expect(activations == 3)
    }

    @Test func presentsExactlyOnce() {
        var opens = 0
        WindowPresentation.present(
            open: { opens += 1 },
            activate: { true },
            schedule: { work in work() }
        )
        #expect(opens == 1)
    }
}
