// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Dibas Sigdel
import Foundation
import Observation
import ServiceManagement

protocol LoginItemServicing {
    var isRegistered: Bool { get }
    var requiresApproval: Bool { get }
    func openLoginItemsSettings()
    func register() throws
    func unregister() throws
}

struct LiveLoginItemService: LoginItemServicing {
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

enum LoginItemFailure: Equatable {
    case registration(String)
    case deregistration(String)
}

@MainActor
@Observable
final class LoginItemModel {
    static let configuredKey = "loginItemConfigured"

    private(set) var isOn: Bool

    private(set) var setupError: LoginItemFailure?

    private(set) var requiresApproval: Bool

    private let service: any LoginItemServicing
    private let defaults: UserDefaults

    init(service: (any LoginItemServicing)? = nil, defaults: UserDefaults? = nil) {
        let service = service ?? LiveLoginItemService()
        let defaults = defaults ?? .standard
        self.service = service
        self.defaults = defaults
        self.isOn = service.isRegistered
        self.requiresApproval = service.requiresApproval
    }

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

    var launchAtLogin: Bool {
        get { isOn }
        set { setOn(newValue) }
    }
}
