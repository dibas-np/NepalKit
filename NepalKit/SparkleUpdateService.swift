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

    override init() {
        let driver = SparkleUserDriverDelegate()
        userDriverDelegate = driver
        super.init()
        driver.onReminderChange = { [weak self] showing in self?.onReminder?(showing) }
        controller = SPUStandardUpdaterController(
            startingUpdater: false,
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
    /// Sparkle prefers this over a SUFeedURL user default or launch argument,
    /// so only the signed Info.plist can choose the feed.
    nonisolated func feedURLString(for updater: SPUUpdater) -> String? {
        Bundle.main.object(forInfoDictionaryKey: "SUFeedURL") as? String
    }

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
            onOutcome?(UpdatePolicy.outcome(forNoUpdateReason: rawReason,
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
