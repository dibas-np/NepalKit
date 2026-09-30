// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Dibas Sigdel
// Excluded from the app-test harness, alongside NepalKitApp.swift: this is the
// only file that imports Sparkle, and the harness links only NepalKitCore. The
// seam it implements — `UpdateServicing` — is Sparkle-free and fully covered by
// the harness, so the boundary is tested even though the implementation is not.
// The transient-launch and outcome decisions live in `UpdatePolicy.swift`, which
// the harness compiles and tests; only framework wiring remains here.
import Sparkle

/// The production `UpdateServicing`, backed by Sparkle 2.9.6 (ADR-0012).
///
/// Uses `SPUStandardUpdaterController` rather than a bare `SPUUpdater` so the
/// framework supplies its own user interface: update alerts, release notes, and
/// the progress window. Reimplementing any of that would be both worse and a
/// security risk, since the installer flow is what the framework's signature
/// verification is built around.
///
/// **No custom fronting is needed.** An `LSUIElement` app's activation policy suppresses becoming
/// frontmost, so the update window could plausibly appear behind whatever the
/// user is looking at. `SPUStandardUserDriver` handles it itself, calling
/// `activateIgnoringOtherApps:YES` before showing a modal window, with the
/// comment that `[NSApp activate]` "does not always work reliably from
/// backgrounded apps when the user initiates checks for updates." That is the
/// same accessory-app activation problem measured in ADR-0011, hit
/// independently by Sparkle's own authors — and it is why that deprecated call
/// is still in the framework. Using the standard user driver is therefore both
/// simpler and more correct than layering `WindowPresentation` on top.
@MainActor
final class SparkleUpdateService: NSObject, UpdateServicing {
    /// Assigned in `init` after `super.init()`, because the controller needs
    /// `self` as its delegate and `self` does not exist until then.
    private var controller: SPUStandardUpdaterController!

    /// Held for the life of the service because `SPUStandardUserDriver` keeps
    /// only a weak reference to its delegate; a local would be deallocated and
    /// the reminder would stop firing without any visible symptom.
    private let userDriverDelegate: SparkleUserDriverDelegate

    var onOutcome: (@MainActor (UpdateOutcome) -> Void)?

    /// Called as the framework presents a scheduled update, and once the user
    /// has attended to it. Drives the menu-bar marker; see
    /// `UpdateCheckModel.isShowingReminder`.
    var onReminder: (@MainActor (Bool) -> Void)?

    var automaticallyChecksForUpdates: Bool {
        get { controller.updater.automaticallyChecksForUpdates }
        set { controller.updater.automaticallyChecksForUpdates = newValue }
    }

    init(startingUpdater: Bool = true) {
        // Set before `super.init()`: this is an NSObject subclass, so every
        // stored property is initialized first. The closure that needs `self`
        // is attached afterwards, once `self` exists.
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
        // `startUpdater` schedules the background check, so it is a one-time
        // call at launch. Throwing means the updater could not be started at
        // all — a real failure worth surfacing rather than swallowing, because
        // an updater that silently never runs reports "up to date" forever.
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
    /// Refuses a scheduled check on a transient launch, where an in-place
    /// self-update cannot succeed: updating replaces the running bundle in
    /// place, which fails from a build directory (the sandbox cannot grant the
    /// installer access to the path) or from a mounted read-only DMG — from
    /// either, Autoupdate aborts with "the bundle being updated … has no
    /// CFBundleVersion". Measured when a /tmp Debug copy failed its self-update
    /// (2026-09-28); the DMG layout gate also opens the packaged app straight
    /// off the mounted image, so that launch is transient too.
    ///
    /// The framework's per-check delegate hook rather than a setting, because
    /// the two available settings both outlive the launch. `register(defaults:)`
    /// only supplies a fallback that an explicit `SUEnableAutomaticChecks`
    /// overrides, and writing the value through `SPUUpdater` persists it — so a
    /// developer build would then disable automatic checks for the installed
    /// copy too. Vetoing the check itself touches no preference and cannot
    /// outlive the process. A manual check is not a scheduled one, so it still
    /// runs, which is what makes a transient build's "Check for Updates…" work.
    nonisolated func updater(
        _ updater: SPUUpdater,
        mayPerformUpdateCheck updateCheck: SPUUpdateCheck,
        error: ()
    ) throws {
        guard updateCheck != .updatesInBackground else { return }
        let transient = MainActor.assumeIsolated {
            UpdatePolicy.isTransientLaunch(installPath: Bundle.main.bundleURL.path)
        }
        guard !transient else {
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

    /// Sparkle reports "no valid update" for several genuinely different
    /// reasons, and the difference matters to a user: being on the latest version
    /// is a good answer, while a feed that could not be fetched or verified is
    /// not. The reason enum is the public way to tell them apart.
    nonisolated func updaterDidNotFindUpdate(_ updater: SPUUpdater, error: Error) {
        let reason = (error as NSError).userInfo[SPUNoUpdateFoundReasonKey] as? SPUNoUpdateFoundReason
        let kind: UpdatePolicy.NoUpdateFoundKind
        switch reason {
        case .onLatestVersion: kind = .onLatestVersion
        case .onNewerThanLatestVersion: kind = .onNewerThanLatestVersion
        default: kind = .other
        }
        MainActor.assumeIsolated {
            onOutcome?(UpdatePolicy.outcome(forNoUpdateFound: kind,
                                            failureReason: error.localizedDescription))
        }
    }
}

/// The gentle reminder: a menu-bar marker while a scheduled update waits to be
/// noticed.
///
/// NepalKit has no Dock icon and no window, so the alert the framework raises
/// for a background check can appear behind other windows to a user who never
/// sees it — Sparkle logs a warning for exactly this case, and it is a real gap
/// here rather than a false positive. The menu bar is the one surface this user
/// actually looks at, so that is where the reminder goes.
///
/// `SPUStandardUserDriver` presents the alert itself; only the marker is added
/// on top, so the install flow is the framework's and is not reimplemented.
private final class SparkleUserDriverDelegate: NSObject, SPUStandardUserDriverDelegate {
    var onReminderChange: (@MainActor (Bool) -> Void)?

    /// Declared only because the two callbacks below implement it. Returning
    /// YES with nothing implemented would silence Sparkle's warning while
    /// leaving the reminder missing, which is the failure the warning exists to
    /// catch.
    var supportsGentleScheduledUpdateReminders: Bool { true }

    /// YES keeps Sparkle's own alert; the marker is additive, not a replacement.
    /// Taking over presentation would mean reimplementing the update window and
    /// the install flow the standard driver already gets right.
    nonisolated func standardUserDriverShouldHandleShowingScheduledUpdate(
        _ update: SUAppcastItem,
        andInImmediateFocus immediateFocus: Bool
    ) -> Bool { true }

    /// `state.userInitiated` is excluded: the user asked, and is looking at the
    /// result, so there is nothing to remind them of. The framework does not
    /// call this again when a known update is brought back to focus, so the
    /// marker cannot be left behind by the user returning to an alert they have
    /// already seen.
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

    /// Backstop for the paths that never reach attention — an install that
    /// completes, or a session ended by the app quitting to update.
    nonisolated func standardUserDriverWillFinishUpdateSession() {
        MainActor.assumeIsolated { onReminderChange?(false) }
    }
}
