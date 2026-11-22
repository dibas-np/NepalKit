// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Dibas Sigdel
import Foundation
import Testing
@testable import NepalKit

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
        var activations = 0
        WindowPresentation.present(
            open: {},
            activate: { activations += 1; return true },
            attempts: 5,
            schedule: { work in work() }
        )
        #expect(activations == 1)
    }

    @Test func retriesWhileTheAppIsNotYetActive() {
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
