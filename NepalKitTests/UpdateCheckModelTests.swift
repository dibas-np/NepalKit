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
        let service = FakeUpdateService()
        let model = UpdateCheckModel(service: service)

        service.report(.failed(reason: "You're up to date!"))
        let text = model.statusText ?? ""
        #expect(text.contains(Strings.updateStatusFailed))
        #expect(text.contains("You're up to date!"))
        #expect(text.contains("“"))
        #expect(text.contains("”"))
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

        let resting = UpdateCheckModel(service: PreviewUpdateService())
        #expect(resting.isUpdateAvailable == false)
        #expect(resting.statusText == Strings.updateStatusNotChecked)
    }
    #endif

    @Test func onlyAFoundUpdateGatesThePopoverButton() {
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
        let appDir = Repository.root.appendingPathComponent("NepalKit")
        let names = try Self.appSources(under: appDir)
        #expect(
            names.contains("AboutSettingsView.swift") && names.contains("PopoverFooter.swift"),
            "the walk did not reach the two surfaces this test guards — found \(names.count) files: \(names)"
        )

        let sources = try names.reduce(into: [String: String]()) { result, name in
            result[name] = try String(contentsOf: appDir.appendingPathComponent(name), encoding: .utf8)
        }

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

        let surfaces = Dictionary(grouping: callSites, by: \.file)

        #expect(
            Set(surfaces.keys) == ["AboutSettingsView.swift", "PopoverFooter.swift"],
            """
            the install flow must be reachable from exactly the popover footer and the \
            Settings About tab. Found triggers in: \(surfaces.mapValues(\.count)). \
            A third surface is a new way into installing.
            """
        )

        for (file, sites) in surfaces {
            #expect(
                sites.count == 1,
                "\(file) has \(sites.count) `updates.checkNow` call sites (\(sites.map(\.line))); expected exactly one"
            )
        }
    }

    @Test func repeatedReminderTransitionsSettleOnTheLastOne() {
        let service = FakeUpdateService()
        let model = UpdateCheckModel(service: service)

        for showing in [true, false, true, false, false] {
            service.remind(showing)
            #expect(model.isShowingReminder == showing)
        }
    }

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
        let service = FakeUpdateService()
        let model = UpdateCheckModel(service: service)
        service.automaticallyChecksForUpdates = false
        model.checkNow()
        #expect(model.automaticallyChecks == false)
    }
}
