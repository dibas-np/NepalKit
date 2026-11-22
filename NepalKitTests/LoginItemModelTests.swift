// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Dibas Sigdel
import Foundation
import Testing
@testable import NepalKit

@MainActor
struct LoginItemModelTests {
    final class MockService: LoginItemServicing {
        var registered: Bool
        var requiresApproval = false
        var registerCalls = 0
        var unregisterCalls = 0
        var openSettingsCalls = 0
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

        func openLoginItemsSettings() {
            openSettingsCalls += 1
        }
    }

    private struct Boom: Error {}

    private let scratch = ScratchDefaults()

    @Test func firstLaunchRegistersOnce() throws {
        let service = MockService()
        let model = LoginItemModel(service: service, defaults: try scratch.make())

        model.ensureDefaultOn()

        #expect(service.registerCalls == 1)
        #expect(model.isOn)
    }

    @Test func secondLaunchDoesNotRegisterAgain() throws {
        let defaults = try scratch.make()
        let first = LoginItemModel(service: MockService(), defaults: defaults)
        first.ensureDefaultOn()

        let service = MockService()
        let second = LoginItemModel(service: service, defaults: defaults)
        second.ensureDefaultOn()

        #expect(service.registerCalls == 0)
    }

    @Test func failedFirstLaunchRecordsTheRegistrationError() throws {
        let service = MockService()
        service.error = Boom()
        let model = LoginItemModel(service: service, defaults: try scratch.make())

        model.ensureDefaultOn()

        #expect(model.setupError == .registration(Boom().localizedDescription))
    }

    @Test func failedFirstLaunchLeavesTheConfiguredFlagUnsetAndRetries() throws {
        let defaults = try scratch.make()
        let service = MockService()
        service.error = Boom()
        LoginItemModel(service: service, defaults: defaults).ensureDefaultOn()

        #expect(!defaults.bool(forKey: LoginItemModel.configuredKey))
        #expect(service.registerCalls == 1)

        let retry = MockService()
        let relaunched = LoginItemModel(service: retry, defaults: defaults)
        relaunched.ensureDefaultOn()

        #expect(retry.registerCalls == 1)
        #expect(relaunched.isOn)
    }

    @Test func anExplicitChoiceAfterAFailedFirstLaunchEndsTheDefault() throws {
        let defaults = try scratch.make()
        let failing = MockService()
        failing.error = Boom()
        LoginItemModel(service: failing, defaults: defaults).ensureDefaultOn()
        LoginItemModel(service: MockService(registered: true), defaults: defaults).setOn(false)

        let relaunch = MockService()
        LoginItemModel(service: relaunch, defaults: defaults).ensureDefaultOn()

        #expect(relaunch.registerCalls == 0)
    }

    @Test func isOnFollowsTheSystemWhenFirstLaunchFails() throws {
        let service = MockService()
        service.error = Boom()
        let model = LoginItemModel(service: service, defaults: try scratch.make())

        model.ensureDefaultOn()

        #expect(!model.isOn)
        #expect(model.setupError != nil)
    }

    @Test func theSameFailureIsReportedIdenticallyFromFirstLaunchAndTheToggle() throws {
        let firstLaunch = MockService()
        firstLaunch.error = Boom()
        let launched = LoginItemModel(service: firstLaunch, defaults: try scratch.make())
        launched.ensureDefaultOn()

        let toggle = MockService()
        toggle.error = Boom()
        let toggled = LoginItemModel(service: toggle, defaults: try scratch.make())
        toggled.setOn(true)

        #expect(launched.setupError != nil)
        #expect(launched.setupError == toggled.setupError)
    }

    @Test func successfulFirstLaunchClearsAnEarlierFailure() throws {
        let defaults = try scratch.make()
        let service = MockService()
        service.error = Boom()
        let model = LoginItemModel(service: service, defaults: defaults)
        model.ensureDefaultOn()
        #expect(model.setupError != nil)

        service.error = nil
        model.ensureDefaultOn()

        #expect(model.isOn)
        #expect(model.setupError == nil)
        #expect(defaults.bool(forKey: LoginItemModel.configuredKey))
    }

    @Test func toggleOffUnregisters() throws {
        let service = MockService(registered: true)
        let model = LoginItemModel(service: service, defaults: try scratch.make())

        model.setOn(false)

        #expect(service.unregisterCalls == 1)
        #expect(!model.isOn)
    }

    @Test func toggleOnRegisters() throws {
        let service = MockService()
        let model = LoginItemModel(service: service, defaults: try scratch.make())

        model.setOn(true)

        #expect(service.registerCalls == 1)
        #expect(model.isOn)
    }

    @Test func toggleOnWhenAlreadyRegisteredDoesNotRestateTheService() throws {
        let service = MockService(registered: true)
        let model = LoginItemModel(service: service, defaults: try scratch.make())

        model.setOn(true)

        #expect(service.registerCalls == 0)
        #expect(model.isOn)
        #expect(model.setupError == nil)
    }

    @Test func toggleOffWhenAlreadyUnregisteredDoesNotRestateTheService() throws {
        let service = MockService()
        let model = LoginItemModel(service: service, defaults: try scratch.make())

        model.setOn(false)

        #expect(service.unregisterCalls == 0)
        #expect(!model.isOn)
        #expect(model.setupError == nil)
    }

    @Test func failedRegistrationLeavesToggleOffAndSurfacesAnError() throws {
        let service = MockService()
        service.error = Boom()
        let model = LoginItemModel(service: service, defaults: try scratch.make())

        model.setOn(true)

        #expect(!model.isOn)
        #expect(model.setupError == .registration(Boom().localizedDescription))
    }

    @Test func failedDeregistrationIsReportedAsADeregistration() throws {
        let service = MockService(registered: true)
        service.error = Boom()
        let model = LoginItemModel(service: service, defaults: try scratch.make())

        model.setOn(false)

        #expect(model.isOn)
        #expect(model.setupError == .deregistration(Boom().localizedDescription))
    }

    @Test func successfulToggleClearsTheError() throws {
        let service = MockService()
        service.error = Boom()
        let model = LoginItemModel(service: service, defaults: try scratch.make())
        model.setOn(true)
        #expect(model.setupError == .registration(Boom().localizedDescription))

        service.error = nil
        model.setOn(true)

        #expect(model.isOn)
        #expect(model.setupError == nil)
    }

    @Test(arguments: [false, true])
    func refreshFollowsExternalChangesWithoutSideEffects(configured: Bool) throws {
        let defaults = try scratch.make()
        if configured { defaults.set(true, forKey: LoginItemModel.configuredKey) }
        let storedFlag = defaults.object(forKey: LoginItemModel.configuredKey) as? Bool
        let service = MockService()
        let model = LoginItemModel(service: service, defaults: defaults)

        service.registered = true
        model.refreshStatus()
        model.refreshStatus()
        #expect(model.isOn)
        #expect(model.launchAtLogin)
        service.registered = false
        model.refreshStatus()
        model.refreshStatus()
        #expect(!model.isOn)
        #expect(service.registerCalls == 0)
        #expect(service.unregisterCalls == 0)
        #expect(defaults.object(forKey: LoginItemModel.configuredKey) as? Bool == storedFlag)
    }

    @Test func refreshPreservesExistingFailure() throws {
        let service = MockService()
        service.error = Boom()
        let model = LoginItemModel(service: service, defaults: try scratch.make())
        model.setOn(true)
        let failure = model.setupError

        service.registered = true
        model.refreshStatus()

        #expect(model.isOn)
        #expect(model.setupError == failure)
        #expect(service.registerCalls == 1)
        #expect(service.unregisterCalls == 0)
    }

    @Test func initReflectsCurrentSystemState() throws {
        let on = LoginItemModel(service: MockService(registered: true), defaults: try scratch.make())
        let off = LoginItemModel(service: MockService(registered: false), defaults: try scratch.make())

        #expect(on.isOn)
        #expect(!off.isOn)
    }

    @Test func approvalHeldBySystemIsSurfacedBesideAnOnToggle() throws {
        let service = MockService(registered: true)
        service.requiresApproval = true
        let model = LoginItemModel(service: service, defaults: try scratch.make())

        #expect(model.isOn)
        #expect(model.requiresApproval)

        model.setOn(true)

        #expect(service.registerCalls == 0)
        #expect(model.requiresApproval)
        #expect(model.setupError == nil)
    }

    @Test func approvalStateIsReadAfterFirstLaunchRegisters() throws {
        let service = MockService()
        let model = LoginItemModel(service: service, defaults: try scratch.make())
        #expect(!model.requiresApproval)

        service.requiresApproval = true
        model.ensureDefaultOn()

        #expect(model.isOn)
        #expect(model.requiresApproval)
    }

    @Test func openLoginItemsSettingsIsForwardedToTheService() throws {
        let service = MockService(registered: true)
        service.requiresApproval = true
        let model = LoginItemModel(service: service, defaults: try scratch.make())

        model.openLoginItemsSettings()

        #expect(service.openSettingsCalls == 1)
        #expect(service.registerCalls == 0)
        #expect(service.unregisterCalls == 0)
    }

    @Test func refreshPicksUpApprovalGrantedOrWithdrawnInSystemSettings() throws {
        let service = MockService(registered: true)
        service.requiresApproval = true
        let model = LoginItemModel(service: service, defaults: try scratch.make())
        #expect(model.requiresApproval)

        service.requiresApproval = false
        model.refreshStatus()
        #expect(!model.requiresApproval)
        #expect(model.isOn)

        service.requiresApproval = true
        model.refreshStatus()
        #expect(model.requiresApproval)
        #expect(service.registerCalls == 0)
        #expect(service.unregisterCalls == 0)
    }
}
