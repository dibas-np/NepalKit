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
    // A pending approval is a registration waiting on the user in System
    // Settings: register() returns without throwing for it, so counting it as
    // unregistered would spring the toggle back with no error to explain why.
    var isRegistered: Bool {
        let status = SMAppService.mainApp.status
        return status == .enabled || status == .requiresApproval
    }

    func register() throws {
        try SMAppService.mainApp.register()
    }

    func unregister() throws {
        try SMAppService.mainApp.unregister()
    }
}

/// The two ways changing the login item can fail, carrying the system's own
/// wording as the payload.
///
/// Typed rather than a bare `String` so a test can pin *which* operation failed
/// without matching its message — the same argument as `UpdateOutcome`, the
/// other Settings-bound service. Two services reporting failure two different
/// ways leaves the next one no pattern to copy; this is the convergence.
///
/// The cases name the operation, not the cause. The errors are opaque
/// `SMAppService` Cocoa errors with nothing in them to classify, so the
/// operation is the only distinction the system actually offers, and the
/// wording is better shown than paraphrased. If a cause ever does need naming —
/// a registration held for approval in System Settings, say — it earns its own
/// case and the view's wording follows from it.
enum LoginItemFailure: Equatable {
    /// `register()` was refused, so the login item could not be turned on.
    case registration(String)
    /// `unregister()` was refused, so the login item could not be turned off.
    case deregistration(String)
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
    private(set) var setupError: LoginItemFailure?

    private let service: any LoginItemServicing
    private let defaults: UserDefaults

    /// Both defaults are built in the body rather than in the signature, for
    /// the same reason as `DisplaySettingsModel`: a default argument is
    /// evaluated in a nonisolated context, so defaulting to constructs of
    /// main-actor-isolated types is fragile under strict isolation checking
    /// even when the initialiser itself is `@MainActor`. Building them in the
    /// body is correct under every toolchain setting. Tests still inject
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
            // The service throws a confusing already-registered error when asked
            // to restate its current state; only drive it when state must change.
            if on {
                if !service.isRegistered { try service.register() }
            } else {
                if service.isRegistered { try service.unregister() }
            }
            setupError = nil
        } catch {
            // Which operation failed is the one thing the system does tell us,
            // and it is what the wording and the test both turn on.
            setupError = on ? .registration(error.localizedDescription)
                            : .deregistration(error.localizedDescription)
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
