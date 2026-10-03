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

    private func freshDefaults() throws -> UserDefaults {
        let name = "NepalKitTests-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: name))
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    @Test func firstLaunchRegistersOnce() throws {
        let service = MockService()
        let model = LoginItemModel(service: service, defaults: try freshDefaults())

        model.ensureDefaultOn()

        #expect(service.registerCalls == 1)
        #expect(model.isOn)
    }

    @Test func secondLaunchDoesNotRegisterAgain() throws {
        let defaults = try freshDefaults()
        let first = LoginItemModel(service: MockService(), defaults: defaults)
        first.ensureDefaultOn()

        let service = MockService()
        let second = LoginItemModel(service: service, defaults: defaults)
        second.ensureDefaultOn()

        #expect(service.registerCalls == 0)
    }

    @Test func failedFirstLaunchRetriesOnNextLaunch() throws {
        let defaults = try freshDefaults()
        let failing = MockService()
        failing.error = Boom()
        LoginItemModel(service: failing, defaults: defaults).ensureDefaultOn()

        let retry = MockService()
        let relaunched = LoginItemModel(service: retry, defaults: defaults)
        relaunched.ensureDefaultOn()

        #expect(retry.registerCalls == 1)
        #expect(relaunched.isOn)
    }

    @Test func failedFirstLaunchRecordsTheRegistrationError() throws {
        let service = MockService()
        service.error = Boom()
        let model = LoginItemModel(service: service, defaults: try freshDefaults())

        model.ensureDefaultOn()

        // Same anchor as `failedRegistrationLeavesToggleOffAndSurfacesAnError`:
        // the very error the fake throws, not a literal, so this pins that the
        // model forwarded the system's description unchanged rather than what
        // Foundation chose to word it as.
        #expect(model.setupError == .registration(Boom().localizedDescription))
    }

    @Test func failedFirstLaunchLeavesTheConfiguredFlagUnsetAndRetries() throws {
        let defaults = try freshDefaults()
        let service = MockService()
        service.error = Boom()
        LoginItemModel(service: service, defaults: defaults).ensureDefaultOn()

        // The retry is the documented policy, so the flag is asserted directly:
        // a new defaults suite starts unset, and a refused registration must
        // leave it that way for the next launch to try again.
        #expect(!defaults.bool(forKey: LoginItemModel.configuredKey))
        #expect(service.registerCalls == 1)

        let retry = MockService()
        LoginItemModel(service: retry, defaults: defaults).ensureDefaultOn()

        #expect(retry.registerCalls == 1)
    }

    @Test func isOnFollowsTheSystemWhenFirstLaunchFails() throws {
        let service = MockService()
        service.error = Boom()
        let model = LoginItemModel(service: service, defaults: try freshDefaults())

        model.ensureDefaultOn()

        // The pairing `setupError`'s own doc comment describes: the throw
        // happens before the service registers, so the system still reports
        // itself unregistered and the toggle must stay off — while the error
        // alongside it is what says why.
        #expect(!model.isOn)
        #expect(model.setupError != nil)
    }

    @Test func theSameFailureIsReportedIdenticallyFromFirstLaunchAndTheToggle() throws {
        let firstLaunch = MockService()
        firstLaunch.error = Boom()
        let launched = LoginItemModel(service: firstLaunch, defaults: try freshDefaults())
        launched.ensureDefaultOn()

        let toggle = MockService()
        toggle.error = Boom()
        let toggled = LoginItemModel(service: toggle, defaults: try freshDefaults())
        toggled.setOn(true)

        // One refusal, two call paths. Comparing the two models to each other
        // rather than to a literal means the mapping is asserted once and
        // cannot drift: a user must not see two messages for one failure
        // depending on whether it happened at first launch or from the toggle.
        #expect(launched.setupError != nil)
        #expect(launched.setupError == toggled.setupError)
    }

    @Test func successfulFirstLaunchClearsAnEarlierFailure() throws {
        let defaults = try freshDefaults()
        let service = MockService()
        service.error = Boom()
        let model = LoginItemModel(service: service, defaults: defaults)
        model.ensureDefaultOn()
        #expect(model.setupError != nil)

        service.error = nil
        model.ensureDefaultOn()

        // The second call is only reached because the refusal left the flag
        // unset — the retry working and the error clearing are the same fact.
        #expect(model.isOn)
        #expect(model.setupError == nil)
        #expect(defaults.bool(forKey: LoginItemModel.configuredKey))
    }

    @Test func toggleOffUnregisters() throws {
        let service = MockService(registered: true)
        let model = LoginItemModel(service: service, defaults: try freshDefaults())

        model.setOn(false)

        #expect(service.unregisterCalls == 1)
        #expect(!model.isOn)
    }

    @Test func toggleOnRegisters() throws {
        let service = MockService()
        let model = LoginItemModel(service: service, defaults: try freshDefaults())

        model.setOn(true)

        #expect(service.registerCalls == 1)
        #expect(model.isOn)
    }

    @Test func toggleOnWhenAlreadyRegisteredDoesNotRestateTheService() throws {
        let service = MockService(registered: true)
        let model = LoginItemModel(service: service, defaults: try freshDefaults())

        model.setOn(true)

        #expect(service.registerCalls == 0)
        #expect(model.isOn)
        #expect(model.setupError == nil)
    }

    @Test func toggleOffWhenAlreadyUnregisteredDoesNotRestateTheService() throws {
        let service = MockService()
        let model = LoginItemModel(service: service, defaults: try freshDefaults())

        model.setOn(false)

        #expect(service.unregisterCalls == 0)
        #expect(!model.isOn)
        #expect(model.setupError == nil)
    }

    @Test func failedRegistrationLeavesToggleOffAndSurfacesAnError() throws {
        let service = MockService()
        service.error = Boom()
        let model = LoginItemModel(service: service, defaults: try freshDefaults())

        model.setOn(true)

        #expect(!model.isOn)
        // The toggle springs back because `isOn` follows the system; the
        // surfaced error is what tells the user why.
        //
        // Compared against the very error the fake throws, not against a
        // literal: what is pinned is that the model forwarded the system's
        // description unchanged, not what Foundation chose to word it as.
        #expect(model.setupError == .registration(Boom().localizedDescription))
    }

    @Test func failedDeregistrationIsReportedAsADeregistration() throws {
        let service = MockService(registered: true)
        service.error = Boom()
        let model = LoginItemModel(service: service, defaults: try freshDefaults())

        model.setOn(false)

        // Same spring-back as the registration failure — the service throws
        // before it unregisters, so the system still reports itself registered.
        #expect(model.isOn)
        // The counterpart the other failure tests cannot reach: every other
        // failure test turns the item *on*, so without this one the two cases
        // could be swapped and the suite would still be green. Asserting the
        // operation is the whole point of typing the failure.
        #expect(model.setupError == .deregistration(Boom().localizedDescription))
    }

    @Test func successfulToggleClearsTheError() throws {
        let service = MockService()
        service.error = Boom()
        let model = LoginItemModel(service: service, defaults: try freshDefaults())
        model.setOn(true)
        #expect(model.setupError == .registration(Boom().localizedDescription))

        service.error = nil
        model.setOn(true)

        #expect(model.isOn)
        #expect(model.setupError == nil)
    }

    @Test(arguments: [false, true])
    func refreshFollowsExternalChangesWithoutSideEffects(configured: Bool) throws {
        let defaults = try freshDefaults()
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
        let model = LoginItemModel(service: service, defaults: try freshDefaults())
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
        let on = LoginItemModel(service: MockService(registered: true), defaults: try freshDefaults())
        let off = LoginItemModel(service: MockService(registered: false), defaults: try freshDefaults())

        #expect(on.isOn)
        #expect(!off.isOn)
    }
}
