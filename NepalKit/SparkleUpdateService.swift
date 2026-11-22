// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Dibas Sigdel
// The only file that imports Sparkle, so it is excluded from the app-test harness.
// The decisions it relies on live in `UpdatePolicy.swift`, which is tested.
import Sparkle

/// The production `UpdateServicing`, backed by Sparkle 2.10.0.
/// Uses the standard controller so Sparkle supplies its own update UI. Its user
/// driver already activates the app before showing a window, so no extra fronting
/// is needed for an `LSUIElement` app.
@MainActor
final class SparkleUpdateService: NSObject, UpdateServicing {
    /// Assigned after `super.init()` because the controller needs `self` as its delegate.
    private var controller: SPUStandardUpdaterController!

    /// Held strongly: `SPUStandardUserDriver` keeps only a weak reference to its delegate.
    private let userDriverDelegate: SparkleUserDriverDelegate

    var onOutcome: (@MainActor (UpdateOutcome) -> Void)?

    var onCycleFinished: (@MainActor () -> Void)?

    /// Toggled while a scheduled update waits to be noticed; drives the menu-bar marker.
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
        // Throwing means the updater never started; surface it rather than report
        // "up to date" forever.
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
    /// Refuses scheduled checks on a transient launch (a build directory or a mounted
    /// DMG), where an in-place update fails. Vetoing per check, rather than changing
    /// the setting, never persists into the installed copy; manual checks still run.
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

    /// Distinguishes "on the latest version" from a feed that could not be fetched or verified.
    nonisolated func updaterDidNotFindUpdate(_ updater: SPUUpdater, error: Error) {
        let rawReason = ((error as NSError).userInfo[SPUNoUpdateFoundReasonKey] as? NSNumber)?.intValue
        MainActor.assumeIsolated {
            let kind = UpdatePolicy.noUpdateKind(rawReason: rawReason)
            onOutcome?(UpdatePolicy.outcome(forNoUpdateFound: kind,
                                            failureReason: error.localizedDescription))
        }
    }

    /// Fetch, parse and signature failures arrive here, not in `updaterDidNotFindUpdate`.
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

    /// Every cycle ends here, including scheduled checks that report no outcome.
    nonisolated func updater(
        _ updater: SPUUpdater,
        didFinishUpdateCycleFor updateCheck: SPUUpdateCheck,
        error: Error?
    ) {
        MainActor.assumeIsolated { onCycleFinished?() }
    }
}

/// Shows a menu-bar marker while a scheduled update waits to be noticed. With no
/// Dock icon, Sparkle's background alert can sit unseen behind other windows.
private final class SparkleUserDriverDelegate: NSObject, SPUStandardUserDriverDelegate {
    var onReminderChange: (@MainActor (Bool) -> Void)?

    /// Only true because the callbacks below implement the reminder.
    var supportsGentleScheduledUpdateReminders: Bool { true }

    /// Keeps Sparkle's own alert; the marker is additive.
    nonisolated func standardUserDriverShouldHandleShowingScheduledUpdate(
        _ update: SUAppcastItem,
        andInImmediateFocus immediateFocus: Bool
    ) -> Bool { true }

    /// User-initiated checks are skipped: the user is already looking at the result.
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

    /// Backstop for sessions that end without user attention, such as a completed install.
    nonisolated func standardUserDriverWillFinishUpdateSession() {
        MainActor.assumeIsolated { onReminderChange?(false) }
    }
}
