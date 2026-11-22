// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Dibas Sigdel
import Foundation
import Observation

/// Testable boundary over the update framework. Sparkle presents its own UI;
/// this exposes only what Settings and the popover footer need.
@MainActor
protocol UpdateServicing: AnyObject {
    /// Starts the updater and schedules background checks. Call once, at launch.
    func start()

    func checkForUpdates()

    var automaticallyChecksForUpdates: Bool { get set }

    /// Read through rather than mirrored: the framework also updates it for scheduled checks.
    var lastCheckDate: Date? { get }

    var onOutcome: (@MainActor (UpdateOutcome) -> Void)? { get set }

    /// Called whatever the result: a scheduled check can move `lastCheckDate`
    /// without any outcome callback.
    var onCycleFinished: (@MainActor () -> Void)? { get set }

    /// `true` as a scheduled update is presented, `false` once the user has attended to it.
    var onReminder: (@MainActor (Bool) -> Void)? { get set }
}

/// A check's outcome. "Could not check" is kept distinct from "up to date".
enum UpdateOutcome: Equatable {
    case upToDate
    case updateAvailable
    /// No network, an unreachable or malformed feed, or a bad signature.
    case failed(reason: String)
}

/// Owns the update surface's state.
@MainActor
@Observable
final class UpdateCheckModel {
    private(set) var outcome: UpdateOutcome?

    /// A scheduled update still waiting for the user's attention; drawn as a
    /// menu-bar marker. Separate from `outcome`, which stays put after the user looks.
    private(set) var isShowingReminder = false

    /// Stored copies so Observation sees changes; re-read from the service whenever
    /// a check reports, finishes or starts.
    private(set) var lastCheckDate: Date?

    private(set) var automaticallyChecks: Bool

    var automaticChecksSetting: Bool {
        get { automaticallyChecks }
        set { setAutomaticallyChecks(newValue) }
    }

    /// Reads back so the toggle shows what the service kept.
    func setAutomaticallyChecks(_ enabled: Bool) {
        service.automaticallyChecksForUpdates = enabled
        automaticallyChecks = service.automaticallyChecksForUpdates
    }

    private let service: any UpdateServicing

    init(service: any UpdateServicing) {
        self.service = service
        self.lastCheckDate = service.lastCheckDate
        self.automaticallyChecks = service.automaticallyChecksForUpdates
        self.service.onOutcome = { [weak self] outcome in
            self?.outcome = outcome
            self?.refreshLastCheckDate()
        }
        self.service.onCycleFinished = { [weak self] in
            self?.refreshLastCheckDate()
        }
        self.service.onReminder = { [weak self] showing in
            if showing { self?.showReminder() } else { self?.dismissReminder() }
        }
    }

    /// Safe to call more than once; the framework ignores the repeat.
    func start() {
        service.start()
        refreshLastCheckDate()
    }

    func checkNow() {
        service.checkForUpdates()
        refreshLastCheckDate()
    }

    private func refreshLastCheckDate() {
        lastCheckDate = service.lastCheckDate
        automaticallyChecks = service.automaticallyChecksForUpdates
    }

    func showReminder() {
        isShowingReminder = true
    }

    func dismissReminder() {
        isShowingReminder = false
    }

    /// Gates the footer's update button. Read from `outcome`, not the reminder,
    /// so a deferred update can still be installed.
    var isUpdateAvailable: Bool { outcome == .updateAvailable }

    /// Before any check this says "not checked", never "up to date".
    var statusText: String? {
        switch outcome {
        case nil: Strings.updateStatusNotChecked
        case .upToDate: Strings.updateStatusUpToDate
        case .updateAvailable: Strings.updateStatusUpdateAvailable
        case .failed(let reason): Strings.updateStatusFailedReason(reason)
        }
    }
}
