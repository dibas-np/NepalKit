// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Dibas Sigdel
import Foundation
import Observation

@MainActor
protocol UpdateServicing: AnyObject {
    func start()

    func checkForUpdates()

    var automaticallyChecksForUpdates: Bool { get set }

    var lastCheckDate: Date? { get }

    var onOutcome: (@MainActor (UpdateOutcome) -> Void)? { get set }

    var onCycleFinished: (@MainActor () -> Void)? { get set }

    var onReminder: (@MainActor (Bool) -> Void)? { get set }
}

enum UpdateOutcome: Equatable {
    case upToDate
    case updateAvailable
    case failed(reason: String)
}

@MainActor
@Observable
final class UpdateCheckModel {
    private(set) var outcome: UpdateOutcome?

    private(set) var isShowingReminder = false

    private(set) var lastCheckDate: Date?

    private(set) var automaticallyChecks: Bool

    var automaticChecksSetting: Bool {
        get { automaticallyChecks }
        set { setAutomaticallyChecks(newValue) }
    }

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

    var isUpdateAvailable: Bool { outcome == .updateAvailable }

    var statusText: String? {
        switch outcome {
        case nil: Strings.updateStatusNotChecked
        case .upToDate: Strings.updateStatusUpToDate
        case .updateAvailable: Strings.updateStatusUpdateAvailable
        case .failed(let reason): Strings.updateStatusFailedReason(reason)
        }
    }
}
