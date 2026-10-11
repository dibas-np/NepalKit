// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Dibas Sigdel
import Foundation
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
    var onReminder: (@MainActor (Bool) -> Void)?
    var lastCheckDate: Date?

    func start() { startCount += 1 }
    func checkForUpdates() { checkCount += 1 }

    /// Simulate the framework reporting a result.
    func report(_ outcome: UpdateOutcome) { onOutcome?(outcome) }

    /// Simulate the framework raising or clearing the gentle reminder.
    func remind(_ showing: Bool) { onReminder?(showing) }
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

    @Test func lastCheckDateIsReadThroughFromTheService() throws {
        // Read-through, not a mirror: the framework owns the fact, and the
        // model's job is only to put it where Settings can show it. A copy
        // here could silently disagree with the framework's own answer.
        let service = FakeUpdateService()
        let model = UpdateCheckModel(service: service)

        #expect(model.lastCheckDate == nil)

        let when = try TestDates.utc(2026, 10, 1, 9, 0)
        service.lastCheckDate = when
        #expect(model.lastCheckDate == when)
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

    @Test func theReminderIsIndependentOfTheReportedOutcome() {
        // The two answer different questions and must not be conflated. An
        // alert raised by a windowless app can be missed entirely, so the
        // marker stays up after the outcome says an update is available, and a
        // later "up to date" does not retract it on its own.
        let service = FakeUpdateService()
        let model = UpdateCheckModel(service: service)

        #expect(model.isShowingReminder == false)

        service.remind(true)
        #expect(model.isShowingReminder)

        service.report(.updateAvailable)
        #expect(model.isShowingReminder, "the outcome is not evidence that the user saw anything")

        service.report(.upToDate)
        #expect(model.isShowingReminder)

        service.remind(false)
        #expect(model.isShowingReminder == false)
    }

    #if DEBUG
    @Test func aPreviewStandInReachesItsStateWithoutStartingTheUpdater() {
        // Asserted here rather than eyeballed in the canvas, because the canvas is
        // not a gate. See `PreviewUpdateService.onOutcome` for why assignment is the
        // only moment a stand-in can report.
        let available = UpdateCheckModel(service: PreviewUpdateService(reporting: .updateAvailable))
        #expect(available.isUpdateAvailable)

        // And the resting state stays reachable, or every other preview in the app
        // would claim an update is waiting for a user who has none.
        let resting = UpdateCheckModel(service: PreviewUpdateService())
        #expect(resting.isUpdateAvailable == false)
        #expect(resting.statusText == Strings.updateStatusNotChecked)
    }
    #endif

    @Test func onlyAFoundUpdateGatesThePopoverButton() {
        // The footer shows its update button on this and nothing else. The
        // last case matters most: a failed check says "I could not find out", which is
        // not an offer to install something.
        let service = FakeUpdateService()
        let model = UpdateCheckModel(service: service)

        #expect(model.isUpdateAvailable == false, "nothing checked yet is not an update")

        service.report(.upToDate)
        #expect(model.isUpdateAvailable == false)

        service.report(.updateAvailable)
        #expect(model.isUpdateAvailable)

        service.report(.failed(reason: "feed unreachable"))
        #expect(model.isUpdateAvailable == false, "a failed check must not offer an install")
    }

    @Test func anAvailableUpdateSurvivesTheUserDismissingTheReminder() {
        // The failure this guards: keying the button to the reminder instead of
        // the outcome. Attending to the alert clears the marker, and a user who
        // chose to defer would then have no way left to install it from anywhere but
        // Settings — having been shown that it existed.
        let service = FakeUpdateService()
        let model = UpdateCheckModel(service: service)

        service.report(.updateAvailable)
        service.remind(true)
        #expect(model.isUpdateAvailable)

        service.remind(false)
        #expect(model.isShowingReminder == false)
        #expect(model.isUpdateAvailable, "the update is still installable after the alert is dismissed")
    }

    /// One place a view reaches the install flow. A pair rather than a preformatted
    /// string, so the assertions group by *which file* owns a trigger and the text
    /// is only built where a human reads it.
    private struct InstallCallSite {
        let file: String
        let line: String
    }

    @Test func thePopoverAndSettingsShareOneTriggerForTheInstallFlow() throws {
        // "One trigger" is a claim about two view files, not about this model, so it
        // has to be checked where those files live: SwiftUI builds view trees by type
        // erasure, leaving nothing at runtime to ask. `checkNow` forwarding to the
        // service is already covered by `checkNowIsForwarded`.
        let appDir = Self.repositoryRoot.appendingPathComponent("NepalKit")
        let names = try Self.appSources(under: appDir)
        #expect(
            names.contains("AboutSettingsView.swift") && names.contains("PopoverFooter.swift"),
            "the walk did not reach the two surfaces this test guards — found \(names.count) files: \(names)"
        )

        // Read once. Two walks over the same tree would be two chances for the two
        // checks below to disagree about what the sources say. The walk is recursive
        // because `AppIntents/` holds eight files a flat listing cannot see, and an
        // App Intent reaching the install flow is exactly what the `.checkForUpdates()`
        // sweep below exists to catch.
        let sources = try names.reduce(into: [String: String]()) { result, name in
            result[name] = try String(contentsOf: appDir.appendingPathComponent(name), encoding: .utf8)
        }

        // Matched as `updates.checkNow` rather than `checkNow()` because that is how
        // both call sites are written: a method reference passed as an action, which
        // never has parentheses. The leading dot also skips the declaration in
        // UpdateCheckModel.swift and the comment in PopoverFooter.swift that names it
        // without a receiver. Doc comments are excluded so documenting the trigger in
        // a view is not a test failure — only calling it is.
        //
        // This is a tripwire against the common mistake, not enforcement: matching
        // text cannot see a call routed through a differently-named property, a key
        // path (`\.checkNow`), or a closure handed down from a third view. If the
        // install flow ever grows past two surfaces, putting the trigger behind a real
        // seam beats loosening what is matched here.
        let callSites = sources.flatMap { name, source -> [InstallCallSite] in
            source
                .split(separator: "\n")
                .compactMap { line -> InstallCallSite? in
                    let trimmed = line.trimmingCharacters(in: .whitespaces)
                    guard trimmed.contains("updates.checkNow"),
                          !trimmed.hasPrefix("//"),
                          !trimmed.hasPrefix("///")
                    else { return nil }
                    return InstallCallSite(file: name, line: trimmed)
                }
        }

        // Both surfaces, and only them: the popover footer and the Settings About
        // tab. A third is a new way into the install flow and wants a decision
        // recorded rather than a silently passing test.
        //
        // Asserted on which files own a trigger, not on how many call sites exist.
        // A count cannot tell the right two files from the wrong two, and it names
        // nothing when it fails — so a surface that broke the rule was reported as
        // a number instead of by name. The per-file count then holds each named
        // surface to a single trigger.
        let surfaces = Dictionary(grouping: callSites, by: \.file)

        #expect(
            Set(surfaces.keys) == ["AboutSettingsView.swift", "PopoverFooter.swift"],
            """
            the install flow must be reachable from exactly the popover footer and the \
            Settings About tab. Found triggers in: \(surfaces.mapValues(\.count)). \
            A third surface is a new way into installing — record the decision, \
            or route it through UpdateCheckModel.checkNow like these two do.
            """
        )

        for (file, sites) in surfaces {
            #expect(
                sites.count == 1,
                "\(file) has \(sites.count) `updates.checkNow` call sites (\(sites.map(\.line))); expected exactly one"
            )
        }

        // And no view reaches the framework's own check directly, which is the same
        // install flow entered without the model in front of it.
        //
        // Matched as `.checkForUpdates()` with the receiver's dot, so the protocol's
        // own declaration and the preview stand-ins' conformance do not read as
        // calls. Only `UpdateCheckModel` may hold one, and `SparkleUpdateService` is
        // where the real one is forwarded to the framework.
        for (name, source) in sources
            where name != "UpdateCheckModel.swift" && name != "SparkleUpdateService.swift" {
            #expect(
                !source.contains(".checkForUpdates()"),
                "\(name) calls the updater's checkForUpdates() directly instead of going through UpdateCheckModel"
            )
        }
    }

    @Test func repeatedReminderTransitionsSettleOnTheLastOne() {
        // The framework can present an update again after the user returns to
        // it, and the end of a session repeats the dismissal. Both are plain
        // assignments, so ordering is the only thing that can go wrong.
        let service = FakeUpdateService()
        let model = UpdateCheckModel(service: service)

        for showing in [true, false, true, false, false] {
            service.remind(showing)
            #expect(model.isShowingReminder == showing)
        }
    }

    /// Upward search for the project file, as in `SymbolTests` — `#filePath` may
    /// or may not be standardized depending on how the compiler was invoked.
    private static var repositoryRoot: URL {
        for base in [URL(fileURLWithPath: #filePath), URL(fileURLWithPath: #filePath).standardizedFileURL] {
            var dir = base.deletingLastPathComponent()
            for _ in 0 ..< 10 {
                if FileManager.default.fileExists(atPath: dir.appendingPathComponent("NepalKit.xcodeproj").path) {
                    return dir
                }
                dir = dir.deletingLastPathComponent()
            }
        }
        return URL(fileURLWithPath: #filePath).deletingLastPathComponent()
    }

    /// Every Swift file under `directory`, as paths relative to it, sorted.
    ///
    /// Recursive because a flat listing cannot see `AppIntents/` — eight files the
    /// app target compiles and the install-flow sweep must not be able to miss.
    /// `Assets.xcassets/` is skipped by name: it is a compiled asset catalogue, not
    /// source. Paths come back relative so a failure message names `AppIntents/X.swift`
    /// rather than an absolute path that differs per machine, and sorted so that
    /// message is the same between runs.
    private static func appSources(under directory: URL) throws -> [String] {
        let root = directory.standardizedFileURL
        guard let enumerator = FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil) else {
            throw CocoaError(.fileReadUnknown)
        }
        let prefix = root.path + "/"
        return enumerator
            .compactMap { $0 as? URL }
            .map { String($0.standardizedFileURL.path.dropFirst(prefix.count)) }
            .filter { $0.hasSuffix(".swift") && !$0.split(separator: "/").contains { $0 == "Assets.xcassets" } }
            .sorted()
    }
}
