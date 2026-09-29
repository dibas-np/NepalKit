// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Dibas Sigdel
// Excluded from the app-test harness, alongside NepalKitApp.swift: this is the
// only file that imports Sparkle, and the harness links only NepalKitCore. The
// seam it implements — `UpdateServicing` — is Sparkle-free and fully covered by
// the harness, so the boundary is tested even though the implementation is not.
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

    var onOutcome: (@MainActor (UpdateOutcome) -> Void)?

    var automaticallyChecksForUpdates: Bool {
        get { controller.updater.automaticallyChecksForUpdates }
        set { controller.updater.automaticallyChecksForUpdates = newValue }
    }

    init(startingUpdater: Bool = true) {
        super.init()
        controller = SPUStandardUpdaterController(
            startingUpdater: startingUpdater,
            updaterDelegate: self,
            userDriverDelegate: nil
        )
    }

    func start() {
        // Automatic checks only make sense for an installed copy: updating
        // replaces the running bundle in place, which cannot succeed from a
        // build directory (the sandbox cannot grant the installer access to
        // the path) or from a mounted read-only DMG — from either, Autoupdate
        // aborts with "the bundle being updated … has no CFBundleVersion".
        // Measured when a /tmp Debug copy failed its self-update (2026-09-28);
        // the DMG layout gate also opens the packaged app straight off the
        // mounted image, so that launch is transient too. A transient launch
        // never schedules automatic checks; manual checks still run off the
        // same started updater.
        let bundlePath = Bundle.main.bundleURL.path
        let transient = bundlePath.hasPrefix("/tmp/")
            || bundlePath.hasPrefix("/private/tmp/")
            || bundlePath.hasPrefix("/Volumes/")
            || bundlePath.contains("/DerivedData/")
        if transient {
            // A launch-local fallback: neither writes nor overrides a real
            // preference, so the developer's own defaults are untouched.
            UserDefaults.standard.register(defaults: ["SUEnableAutomaticChecks": false])
        }
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
    nonisolated func updater(_ updater: SPUUpdater, didFindValidUpdate item: SUAppcastItem) {
        MainActor.assumeIsolated { onOutcome?(.updateAvailable) }
    }

    /// Sparkle reports "no valid update" for several genuinely different
    /// reasons, and the difference matters to a user: being on the latest version
    /// is a good answer, while a feed that could not be fetched or verified is
    /// not. The reason enum is the public way to tell them apart.
    nonisolated func updaterDidNotFindUpdate(_ updater: SPUUpdater, error: Error) {
        let reason = (error as NSError).userInfo[SPUNoUpdateFoundReasonKey] as? SPUNoUpdateFoundReason
        MainActor.assumeIsolated {
            switch reason {
            case .onLatestVersion, .onNewerThanLatestVersion:
                onOutcome?(.upToDate)
            default:
                onOutcome?(.failed(reason: error.localizedDescription))
            }
        }
    }
}
