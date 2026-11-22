// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Dibas Sigdel
import Foundation
import Testing
@testable import NepalKit

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
        // "Not checked" must not read as "up to date".
        let model = UpdateCheckModel(service: FakeUpdateService())

        #expect(model.outcome == nil)
        #expect(model.statusText == Strings.updateStatusNotChecked)
        #expect(model.statusText != Strings.updateStatusUpToDate)
    }

    @Test func lastCheckDateIsReadFromTheServiceAtInit() throws {
        let service = FakeUpdateService()
        let when = try TestDates.utc(2026, 10, 1, 9, 0)
        service.lastCheckDate = when

        #expect(UpdateCheckModel(service: service).lastCheckDate == when)
    }

    @Test func aReportedOutcomeRefreshesLastCheckDate() throws {
        let service = FakeUpdateService()
        let model = UpdateCheckModel(service: service)
        #expect(model.lastCheckDate == nil)

        let when = try TestDates.utc(2026, 10, 1, 9, 0)
        service.lastCheckDate = when
        service.report(.upToDate)

        #expect(model.lastCheckDate == when)
    }

    @Test func aFinishedCycleWithNoOutcomeRefreshesLastCheckDate() throws {
        // A scheduled background check can finish without any outcome
        // callback; the cycle-finished signal still moves the date.
        let service = FakeUpdateService()
        let model = UpdateCheckModel(service: service)

        let when = try TestDates.utc(2026, 10, 2, 9, 0)
        service.lastCheckDate = when
        service.finishCycle()

        #expect(model.lastCheckDate == when)
        #expect(model.outcome == nil)
    }

    @Test func automaticallyChecksIsReadFromTheServiceAtInit() {
        let service = FakeUpdateService()
        service.automaticallyChecksForUpdates = false

        let model = UpdateCheckModel(service: service)

        #expect(model.automaticallyChecks == false)
        // Reading at init must not write back.
        #expect(service.automaticWrites == 1)
    }

    @Test func aFailedCheckIsNotReportedAsUpToDate() {
        let service = FakeUpdateService()
        let model = UpdateCheckModel(service: service)

        service.report(.failed(reason: "feed unreachable"))
        #expect(model.statusText == Strings.updateStatusFailedReason("feed unreachable"))
        #expect(model.statusText != Strings.updateStatusUpToDate)
    }

    @Test func aFrameworkReasonCannotContradictTheFailure() {
        // Sparkle's start-failure description can read "You're up to date!", so
        // the reason is quoted to keep it apart from our failure sentence.
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
        let outcomes: [UpdateOutcome] = [.upToDate, .updateAvailable, .failed(reason: "x")]
        let rendered = outcomes.map(Self.renderedText(for:))
        #expect(Set(rendered).count == 3, "collapsed to: \(rendered)")
    }

    private static func renderedText(for outcome: UpdateOutcome) -> String? {
        let service = FakeUpdateService()
        let model = UpdateCheckModel(service: service)
        service.report(outcome)
        return model.statusText
    }

    @Test func automaticChecksRoundTripThroughTheService() {
        let service = FakeUpdateService()
        let model = UpdateCheckModel(service: service)

        model.setAutomaticallyChecks(false)
        #expect(model.automaticallyChecks == false)
        #expect(service.automaticallyChecksForUpdates == false)

        model.setAutomaticallyChecks(true)
        #expect(service.automaticallyChecksForUpdates == true)
        #expect(service.automaticWrites == 2)
    }

    @Test func theReminderIsIndependentOfTheReportedOutcome() {
        // An alert from a windowless app can be missed, so the reminder stays
        // up regardless of later outcomes.
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
        let available = UpdateCheckModel(service: PreviewUpdateService(reporting: .updateAvailable))
        #expect(available.isUpdateAvailable)

        // The resting state must not claim an update is waiting.
        let resting = UpdateCheckModel(service: PreviewUpdateService())
        #expect(resting.isUpdateAvailable == false)
        #expect(resting.statusText == Strings.updateStatusNotChecked)
    }
    #endif

    @Test func onlyAFoundUpdateGatesThePopoverButton() {
        // A failed check is not an offer to install.
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
        // The button follows the outcome, not the reminder, so dismissing the
        // alert doesn't take away the way to install.
        let service = FakeUpdateService()
        let model = UpdateCheckModel(service: service)

        service.report(.updateAvailable)
        service.remind(true)
        #expect(model.isUpdateAvailable)

        service.remind(false)
        #expect(model.isShowingReminder == false)
        #expect(model.isUpdateAvailable, "the update is still installable after the alert is dismissed")
    }

    private struct InstallCallSite {
        let file: String
        let line: String
    }

    @Test func thePopoverAndSettingsShareOneTriggerForTheInstallFlow() throws {
        // SwiftUI leaves nothing to inspect at runtime, so read the view sources.
        let appDir = Self.repositoryRoot.appendingPathComponent("NepalKit")
        let names = try Self.appSources(under: appDir)
        #expect(
            names.contains("AboutSettingsView.swift") && names.contains("PopoverFooter.swift"),
            "the walk did not reach the two surfaces this test guards — found \(names.count) files: \(names)"
        )

        // Recursive, so App Intents are covered too.
        let sources = try names.reduce(into: [String: String]()) { result, name in
            result[name] = try String(contentsOf: appDir.appendingPathComponent(name), encoding: .utf8)
        }

        // Both call sites pass a method reference, so there are no parentheses.
        // Text matching is a tripwire, not enforcement: a key path or a closure
        // handed down from another view would get past it.
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

        // Exactly the popover footer and the Settings About tab, one trigger each.
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

        // No view may call the framework's check directly. The leading dot skips
        // the protocol declaration and the preview stand-ins' conformance.
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
        // it, and the end of a session repeats the dismissal.
        let service = FakeUpdateService()
        let model = UpdateCheckModel(service: service)

        for showing in [true, false, true, false, false] {
            service.remind(showing)
            #expect(model.isShowingReminder == showing)
        }
    }

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

    /// Every Swift file under `directory`, as sorted relative paths.
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

    @Test func automaticChecksFollowTheServiceWhenItChangesElsewhere() {
        // Sparkle can change the setting itself (its first-launch prompt);
        // the model reads it back rather than keeping a copy that drifts.
        let service = FakeUpdateService()
        let model = UpdateCheckModel(service: service)
        service.automaticallyChecksForUpdates = false
        model.checkNow()
        #expect(model.automaticallyChecks == false)
    }
}
