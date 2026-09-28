// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Dibas Sigdel
import Testing
@testable import NepalKit

/// Test double, same shape as the `LoginItemServicing` mock. The production
/// service needs Sparkle and a live updater session, which the harness does not
/// link, so this is how the model's own logic is covered.
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
        #expect(model.statusText == Strings.updateStatusFailedReason("feed unreachable"))
        #expect(model.statusText != Strings.updateStatusUpToDate)
    }

    @Test func aFrameworkReasonCannotContradictTheFailure() {
        // Found by running the app, not by reading this: the status line read
        // "Could not check for updates: You're up to date!" Sparkle's
        // localizedDescription for a start failure is phrased for its own UI
        // and does not always describe the check. Spliced straight into our
        // sentence the line asserts both outcomes at once, which is worse than
        // either answer on its own.
        //
        // The fix is presentation, not classification: the outcome is still
        // `.failed`, and the reason is still shown, but it is quoted so the two
        // claims stay separable and the blame is visibly the framework's.
        let service = FakeUpdateService()
        let model = UpdateCheckModel(service: service)

        service.report(.failed(reason: "You're up to date!"))
        let text = model.statusText ?? ""
        #expect(text.contains(Strings.updateStatusFailed))
        #expect(text.contains("You're up to date!"))
        // The contradiction is marked as foreign text, not asserted by us.
        #expect(text.contains("“"))
        #expect(text.contains("”"))
        // And it must not read as a bare success claim anywhere in the line.
        #expect(!text.hasSuffix(Strings.updateStatusUpToDate))
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
