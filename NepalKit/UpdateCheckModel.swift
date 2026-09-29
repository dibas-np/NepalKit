// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Dibas Sigdel
import Observation

/// Testable boundary over the update framework.
///
/// Mirrors `LoginItemServicing` deliberately: the system is behind a protocol so
/// the model that owns the user-facing state is testable without the framework,
/// a network, a published feed, or a signing key.
///
/// Deliberately narrow. Only the two operations the Settings surface offers:
/// "check now" and "automatically check". Whether an update is *available* is
/// Sparkle's business, and its own user interface presents the result; this does
/// not reimplement any of it.
///
/// `Outcome` is recorded by the service rather than inferred here, because
/// Sparkle's own result reporting is the only trustworthy source for it. The
/// distinction that matters to a user is "up to date" versus "I could not find
/// out" — conflating them tells someone they are current when the truth is that
/// nothing was checked, which is exactly the failure mode an updater must not
/// have.
@MainActor
protocol UpdateServicing: AnyObject {
    /// Begin the updater. Call once, at launch. Sparkle must be started before
    /// any check is requested, and starting it is what schedules the automatic
    /// background check.
    func start()

    /// Ask for an immediate check, showing the framework's own result UI.
    func checkForUpdates()

    /// Whether background checks on a schedule are enabled. The user can turn
    /// this off; an updater that can only be triggered manually is opt-in and a
    /// user who never opens Settings never learns about updates.
    var automaticallyChecksForUpdates: Bool { get set }

    /// Called as the framework reports the outcome of a check.
    var onOutcome: (@MainActor (UpdateOutcome) -> Void)? { get set }

    /// Called with `true` as a scheduled update is presented, and `false` once
    /// the user has attended to it or the update session has finished.
    var onReminder: (@MainActor (Bool) -> Void)? { get set }
}

/// The outcomes a check can have, as distinct answers rather than a boolean.
enum UpdateOutcome: Equatable {
    case upToDate
    /// An update was found; the framework has taken over the presentation.
    case updateAvailable
    /// The check could not complete — no network, feed unreachable, feed
    /// malformed, or the feed's signature did not verify. Not the same as
    /// "up to date".
    case failed(reason: String)
}

/// Owns the update surface's state.
@MainActor
@Observable
final class UpdateCheckModel {
    /// Last reported outcome, or nil when nothing has been checked yet.
    private(set) var outcome: UpdateOutcome?

    /// Whether a scheduled update is being shown and still needs the user's
    /// attention. Drawn as a marker on the menu-bar date.
    ///
    /// Not derived from `outcome`, which answers "what did the last check
    /// find" and stays put once an update is found. This answers the different
    /// question the marker exists for: has the user actually looked. An alert
    /// raised by a windowless app is easy to miss entirely, so the marker
    /// persists until the framework reports attention or the session ends.
    private(set) var isShowingReminder = false

    private let service: any UpdateServicing

    init(service: any UpdateServicing) {
        self.service = service
        self.service.onOutcome = { [weak self] outcome in
            self?.outcome = outcome
        }
        self.service.onReminder = { [weak self] showing in
            if showing { self?.showReminder() } else { self?.dismissReminder() }
        }
    }

    /// Sparkle must be started before a check is requested, and starting it is
    /// what schedules the automatic background check. Safe to call more than
    /// once; the framework ignores the repeat.
    func start() {
        service.start()
    }

    func checkNow() {
        service.checkForUpdates()
    }

    /// Called as the framework is about to present a scheduled update.
    func showReminder() {
        isShowingReminder = true
    }

    /// Called once the user has attended to the update — brought the alert to
    /// focus, or chosen to install, skip, or defer it.
    func dismissReminder() {
        isShowingReminder = false
    }

    var automaticallyChecks: Bool {
        get { service.automaticallyChecksForUpdates }
        set { service.automaticallyChecksForUpdates = newValue }
    }

    /// What to show under the control. Deliberately says nothing before a check
    /// has happened, rather than implying the app is current — "not yet checked"
    /// and "up to date" are different facts and only one of them is free.
    var statusText: String? {
        switch outcome {
        case nil: Strings.updateStatusNotChecked
        case .upToDate: Strings.updateStatusUpToDate
        case .updateAvailable: Strings.updateStatusUpdateAvailable
        case .failed(let reason): Strings.updateStatusFailedReason(reason)
        }
    }
}
