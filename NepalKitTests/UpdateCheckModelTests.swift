// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Dibas Sigdel
import Testing
@testable import NepalKit

/// Test double, same shape as the `LoginItemServicing` mock. The production
/// service needs a running updater, a published feed and a signing key, none of
/// which exist yet, so this is how the model's own logic is covered.
@MainActor
final class FakeUpdateService: UpdateServicing {
    private(set) var startCount = 0
    private(set) var checkCount = 0
    var automaticallyChecksForUpdates = true
    var onOutcome: (@MainActor (UpdateOutcome) -> Void)?

    func start() { startCount += 1 }
    func checkForUpdates() { checkCount += 1 }

    /// Simulate the framework reporting a result.
    func report(_ outcome: UpdateOutcome) { onOutcome?(outcome) }
}

@MainActor
struct UpdateCheckModelTests {
    @Test func startingIsForwarded() {
        let service = FakeUpdateService()
        let model = UpdateCheckModel(service: service)

        model.start()

        #expect(service.startCount == 1)
    }

    @Test func checkNowIsForwarded() {
        let service = FakeUpdateService()
        let model = UpdateCheckModel(service: service)

        model.checkNow()

        #expect(service.checkCount == 1)
    }

    @Test func outcomeIsNilUntilSomethingIsReported() {
        // The distinction this model exists to keep: "not checked" is not
        // "up to date", so the default state must not read as current.
        let model = UpdateCheckModel(service: FakeUpdateService())

        #expect(model.outcome == nil)
        #expect(model.statusText == Strings.updateStatusNotChecked)
        #expect(model.statusText != Strings.updateStatusUpToDate)
    }

    @Test func aFailedCheckIsNotReportedAsUpToDate() {
        // The failure mode an updater must not have: telling someone they are
        // current when the truth is that nothing could be verified.
        let service = FakeUpdateService()
        let model = UpdateCheckModel(service: service)

        service.report(.failed(reason: "feed unreachable"))
        #expect(model.statusText == Strings.updateStatusFailed)
        #expect(model.statusText != Strings.updateStatusUpToDate)
    }

    @Test(arguments: [
        (UpdateOutcome.upToDate, Strings.updateStatusUpToDate),
        (.updateAvailable, Strings.updateStatusUpdateAvailable),
    ])
    func eachOutcomeHasItsOwnText(outcome: UpdateOutcome, expected: String) {
        let service = FakeUpdateService()
        let model = UpdateCheckModel(service: service)

        service.report(outcome)

        #expect(model.statusText == expected)
    }

    @Test func everyOutcomeHasDistinctText() {
        // Guards against a future edit collapsing two cases into one string,
        // which would reintroduce the conflation this type prevents.
        let outcomes: [UpdateOutcome] = [.upToDate, .updateAvailable, .failed(reason: "x")]
        let rendered = outcomes.map(Self.renderedText(for:))
        #expect(Set(rendered).count == 3, "collapsed to: \(rendered)")
    }

    /// Renders one outcome in isolation, for the distinctness check above.
    private static func renderedText(for outcome: UpdateOutcome) -> String? {
        let service = FakeUpdateService()
        let model = UpdateCheckModel(service: service)
        service.report(outcome)
        return model.statusText
    }

    @Test func automaticChecksRoundTripThroughTheService() {
        let service = FakeUpdateService()
        let model = UpdateCheckModel(service: service)

        model.automaticallyChecks = false
        #expect(model.automaticallyChecks == false)
        #expect(service.automaticallyChecksForUpdates == false)

        model.automaticallyChecks = true
        #expect(service.automaticallyChecksForUpdates == true)
    }
}
