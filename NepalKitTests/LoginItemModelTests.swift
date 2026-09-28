// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Dibas Sigdel
import Foundation
import Testing
@testable import NepalKit

/// Launch-at-login must default on at first launch and stay user-controllable.
/// The system boundary is mocked: tests never touch SMAppService.
@MainActor
struct LoginItemModelTests {
    final class MockService: LoginItemServicing {
        var registered: Bool
        var registerCalls = 0
        var unregisterCalls = 0
        var error: (any Error)?

        init(registered: Bool = false) { self.registered = registered }

        var isRegistered: Bool { registered }

        func register() throws {
            registerCalls += 1
            if let error { throw error }
            registered = true
        }

        func unregister() throws {
            unregisterCalls += 1
            if let error { throw error }
            registered = false
        }
    }

    private struct Boom: Error {}

    private func freshDefaults() -> UserDefaults {
        let name = "NepalKitTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    @Test func firstLaunchRegistersOnce() {
        let service = MockService()
        let model = LoginItemModel(service: service, defaults: freshDefaults())

        model.ensureDefaultOn()

        #expect(service.registerCalls == 1)
        #expect(model.isOn)
    }

    @Test func secondLaunchDoesNotRegisterAgain() {
        let defaults = freshDefaults()
        let first = LoginItemModel(service: MockService(), defaults: defaults)
        first.ensureDefaultOn()

        let service = MockService()
        let second = LoginItemModel(service: service, defaults: defaults)
        second.ensureDefaultOn()

        #expect(service.registerCalls == 0)
    }

    @Test func failedFirstLaunchRetriesOnNextLaunch() {
        let defaults = freshDefaults()
        let failing = MockService()
        failing.error = Boom()
        LoginItemModel(service: failing, defaults: defaults).ensureDefaultOn()

        let retry = MockService()
        let relaunched = LoginItemModel(service: retry, defaults: defaults)
        relaunched.ensureDefaultOn()

        #expect(retry.registerCalls == 1)
        #expect(relaunched.isOn)
    }

    @Test func toggleOffUnregisters() {
        let service = MockService(registered: true)
        let model = LoginItemModel(service: service, defaults: freshDefaults())

        model.setOn(false)

        #expect(service.unregisterCalls == 1)
        #expect(!model.isOn)
    }

    @Test func toggleOnRegisters() {
        let service = MockService()
        let model = LoginItemModel(service: service, defaults: freshDefaults())

        model.setOn(true)

        #expect(service.registerCalls == 1)
        #expect(model.isOn)
    }

    @Test func failedRegistrationLeavesToggleOffAndSurfacesAnError() {
        let service = MockService()
        service.error = Boom()
        let model = LoginItemModel(service: service, defaults: freshDefaults())

        model.setOn(true)

        #expect(!model.isOn)
        // The toggle springs back because `isOn` follows the system; the
        // surfaced error is what tells the user why.
        #expect(model.setupError != nil)
    }

    @Test func successfulToggleClearsTheError() {
        let service = MockService()
        service.error = Boom()
        let model = LoginItemModel(service: service, defaults: freshDefaults())
        model.setOn(true)
        #expect(model.setupError != nil)

        service.error = nil
        model.setOn(true)

        #expect(model.isOn)
        #expect(model.setupError == nil)
    }

    @Test func initReflectsCurrentSystemState() {
        let on = LoginItemModel(service: MockService(registered: true), defaults: freshDefaults())
        let off = LoginItemModel(service: MockService(registered: false), defaults: freshDefaults())

        #expect(on.isOn)
        #expect(!off.isOn)
    }
}
