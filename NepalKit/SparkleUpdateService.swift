// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Dibas Sigdel
import Sparkle

@MainActor
final class SparkleUpdateService: NSObject, UpdateServicing {
    private var controller: SPUStandardUpdaterController!

    /// Held strongly: `SPUStandardUserDriver` keeps only a weak reference to its delegate.
    private let userDriverDelegate: SparkleUserDriverDelegate

    var onOutcome: (@MainActor (UpdateOutcome) -> Void)?

    var onCycleFinished: (@MainActor () -> Void)?

    var onReminder: (@MainActor (Bool) -> Void)?

    var automaticallyChecksForUpdates: Bool {
        get { controller.updater.automaticallyChecksForUpdates }
        set { controller.updater.automaticallyChecksForUpdates = newValue }
    }

    var lastCheckDate: Date? {
        controller.updater.lastUpdateCheckDate
    }

    init(startingUpdater: Bool = true) {
        let driver = SparkleUserDriverDelegate()
        userDriverDelegate = driver
        super.init()
        driver.onReminderChange = { [weak self] showing in self?.onReminder?(showing) }
        controller = SPUStandardUpdaterController(
            startingUpdater: startingUpdater,
            updaterDelegate: self,
            userDriverDelegate: driver
        )
    }

    func start() {
        do {
            try controller.updater.start()
        } catch {
            onOutcome?(.failed(reason: error.localizedDescription))
        }
    }

    func checkForUpdates() {
        controller.updater.checkForUpdates()
    }
}

extension SparkleUpdateService: SPUUpdaterDelegate {
    nonisolated func updater(
        _ updater: SPUUpdater,
        mayPerformUpdateCheck updateCheck: SPUUpdateCheck,
        error: ()
    ) throws {
        let vetoed = MainActor.assumeIsolated {
            UpdatePolicy.vetoesCheck(
                isScheduled: updateCheck == .updatesInBackground,
                installPath: Bundle.main.bundleURL.path
            )
        }
        guard !vetoed else {
            throw NSError(
                domain: "NepalKit.Update",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: Strings.updateCheckSkippedTransientLaunch]
            )
        }
    }

    nonisolated func updater(_ updater: SPUUpdater, didFindValidUpdate item: SUAppcastItem) {
        MainActor.assumeIsolated { onOutcome?(.updateAvailable) }
    }

    nonisolated func updaterDidNotFindUpdate(_ updater: SPUUpdater, error: Error) {
        let rawReason = ((error as NSError).userInfo[SPUNoUpdateFoundReasonKey] as? NSNumber)?.intValue
        MainActor.assumeIsolated {
            let kind = UpdatePolicy.noUpdateKind(rawReason: rawReason)
            onOutcome?(UpdatePolicy.outcome(forNoUpdateFound: kind,
                                            failureReason: error.localizedDescription))
        }
    }

    nonisolated func updater(_ updater: SPUUpdater, didAbortWithError error: Error) {
        let nsError = error as NSError
        let domain = nsError.domain
        let code = nsError.code
        let description = error.localizedDescription
        MainActor.assumeIsolated {
            guard let outcome = UpdatePolicy.outcome(
                forAbortedCheckDomain: domain,
                code: code,
                description: description
            ) else { return }
            onOutcome?(outcome)
        }
    }

    nonisolated func updater(
        _ updater: SPUUpdater,
        didFinishUpdateCycleFor updateCheck: SPUUpdateCheck,
        error: Error?
    ) {
        MainActor.assumeIsolated { onCycleFinished?() }
    }
}

/// With no Dock icon, Sparkle's background alert can sit unseen behind other windows.
private final class SparkleUserDriverDelegate: NSObject, SPUStandardUserDriverDelegate {
    var onReminderChange: (@MainActor (Bool) -> Void)?

    var supportsGentleScheduledUpdateReminders: Bool { true }

    nonisolated func standardUserDriverShouldHandleShowingScheduledUpdate(
        _ update: SUAppcastItem,
        andInImmediateFocus immediateFocus: Bool
    ) -> Bool { true }

    nonisolated func standardUserDriverWillHandleShowingUpdate(
        _ handleShowingUpdate: Bool,
        forUpdate update: SUAppcastItem,
        state: SPUUserUpdateState
    ) {
        guard !state.userInitiated else { return }
        MainActor.assumeIsolated { onReminderChange?(true) }
    }

    nonisolated func standardUserDriverDidReceiveUserAttention(forUpdate update: SUAppcastItem) {
        MainActor.assumeIsolated { onReminderChange?(false) }
    }

    nonisolated func standardUserDriverWillFinishUpdateSession() {
        MainActor.assumeIsolated { onReminderChange?(false) }
    }
}
