// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Dibas Sigdel
import Foundation
import Observation
import ServiceManagement

/// Testable boundary over the system login-item service.
/// Production code uses `LiveLoginItemService` (SMAppService);
/// tests inject a mock. The boundary is never touched by tests.
protocol LoginItemServicing {
    var isRegistered: Bool { get }
    func register() throws
    func unregister() throws
}

/// Live login-item service backed by the modern system login-item API.
/// No entitlement is needed for the main app's own login item.
struct LiveLoginItemService: LoginItemServicing {
    var isRegistered: Bool { SMAppService.mainApp.status == .enabled }

    func register() throws {
        try SMAppService.mainApp.register()
    }

    func unregister() throws {
        try SMAppService.mainApp.unregister()
    }
}

/// Owns the launch-at-login toggle. The system is the source of truth for
/// the on/off state; only the "already configured the default" flag is
/// persisted, so first launch registers once and never overrides the user.
@MainActor
@Observable
final class LoginItemModel {
    static let configuredKey = "loginItemConfigured"

    private(set) var isOn: Bool

    /// The last failure reported by the login-item service, if any. `isOn`
    /// follows the system either way, so without this a refused registration
    /// only makes the toggle spring back, never saying why.
    private(set) var setupError: String?

    private let service: any LoginItemServicing
    private let defaults: UserDefaults

    /// Both defaults are built in the body rather than in the signature, for
    /// the same reason as `DisplaySettingsModel`: a default argument is
    /// evaluated nonisolated, and `LiveLoginItemService()` and
    /// `UserDefaults.standard` are main-actor isolated. Tests still inject
    /// either one explicitly, so the call sites are unchanged.
    init(service: (any LoginItemServicing)? = nil, defaults: UserDefaults? = nil) {
        let service = service ?? LiveLoginItemService()
        let defaults = defaults ?? .standard
        self.service = service
        self.defaults = defaults
        self.isOn = service.isRegistered
    }

    /// Registers at first launch so the date is in the menu bar from sign-in.
    /// Runs until it succeeds: afterwards the user's toggle choice is never
    /// overridden. The flag is set only on confirmed registration, so a
    /// failed first launch retries on the next launch instead of giving up.
    func ensureDefaultOn() {
        guard !defaults.bool(forKey: Self.configuredKey) else { return }
        try? service.register()
        isOn = service.isRegistered
        if isOn {
            defaults.set(true, forKey: Self.configuredKey)
        }
    }

    func setOn(_ on: Bool) {
        do {
            if on {
                try service.register()
            } else {
                try service.unregister()
            }
            setupError = nil
        } catch {
            setupError = error.localizedDescription
        }
        isOn = service.isRegistered
    }

    /// Binding target for the Settings toggle: writing runs the same
    /// register/unregister path as `setOn(_:)`.
    var launchAtLogin: Bool {
        get { isOn }
        set { setOn(newValue) }
    }
}
