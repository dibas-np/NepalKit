// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Dibas Sigdel
import Foundation
import Observation
import ServiceManagement

/// The system login-item service, injectable for tests.
protocol LoginItemServicing {
    var isRegistered: Bool { get }
    /// Registered, but held by macOS until the user allows it in System Settings.
    var requiresApproval: Bool { get }
    func openLoginItemsSettings()
    func register() throws
    func unregister() throws
}

/// Login-item service backed by `SMAppService`.
struct LiveLoginItemService: LoginItemServicing {
    // A registration awaiting approval counts as registered: `register()` succeeded,
    // and reporting it as off would flip the toggle back with no explanation.
    var isRegistered: Bool {
        let status = SMAppService.mainApp.status
        return status == .enabled || status == .requiresApproval
    }

    var requiresApproval: Bool {
        SMAppService.mainApp.status == .requiresApproval
    }

    func openLoginItemsSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }

    func register() throws {
        try SMAppService.mainApp.register()
    }

    func unregister() throws {
        try SMAppService.mainApp.unregister()
    }
}

/// A failed login-item change, carrying the system's own message. The errors are
/// opaque, so the operation is the only distinction worth keeping.
enum LoginItemFailure: Equatable {
    case registration(String)
    case deregistration(String)
}

/// The launch-at-login toggle. The system owns the on/off state; only the
/// "default already applied" flag is persisted.
@MainActor
@Observable
final class LoginItemModel {
    static let configuredKey = "loginItemConfigured"

    private(set) var isOn: Bool

    /// The last failure from the service, shown so a refused change isn't silent.
    private(set) var setupError: LoginItemFailure?

    /// Registered, but macOS won't launch the app at login until the user allows it.
    private(set) var requiresApproval: Bool

    private let service: any LoginItemServicing
    private let defaults: UserDefaults

    /// Defaults are built in the body: a default argument is evaluated in a
    /// nonisolated context.
    init(service: (any LoginItemServicing)? = nil, defaults: UserDefaults? = nil) {
        let service = service ?? LiveLoginItemService()
        let defaults = defaults ?? .standard
        self.service = service
        self.defaults = defaults
        self.isOn = service.isRegistered
        self.requiresApproval = service.requiresApproval
    }

    /// Registers at first launch. The flag is set only after a confirmed registration,
    /// so a failure retries next launch; after that the user's choice is never overridden.
    func ensureDefaultOn() {
        guard !defaults.bool(forKey: Self.configuredKey) else { return }
        do {
            try service.register()
            setupError = nil
        } catch {
            setupError = Self.failure(from: error, turningOn: true)
        }
        readStatus()
        if isOn {
            defaults.set(true, forKey: Self.configuredKey)
        }
    }

    func refreshStatus() {
        readStatus()
    }

    func openLoginItemsSettings() {
        service.openLoginItemsSettings()
    }

    private func readStatus() {
        isOn = service.isRegistered
        requiresApproval = service.requiresApproval
    }

    func setOn(_ on: Bool) {
        do {
            // Registering when already registered throws, so only act on a change.
            if on {
                if !service.isRegistered { try service.register() }
            } else {
                if service.isRegistered { try service.unregister() }
            }
            setupError = nil
        } catch {
            setupError = Self.failure(from: error, turningOn: on)
        }
        readStatus()
    }

    private static func failure(from error: any Error, turningOn: Bool) -> LoginItemFailure {
        turningOn ? .registration(error.localizedDescription)
                  : .deregistration(error.localizedDescription)
    }

    /// Binding target for the Settings toggle.
    var launchAtLogin: Bool {
        get { isOn }
        set { setOn(newValue) }
    }
}
