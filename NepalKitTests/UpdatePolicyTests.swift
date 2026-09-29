// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Dibas Sigdel
import Testing
@testable import NepalKit

struct UpdatePolicyTests {

    @Test func transientLaunchesAreThePathsSelfUpdateCannotSucceedFrom() {
        #expect(UpdatePolicy.isTransientLaunch(installPath: "/tmp/NepalKit-debug.app"))
        #expect(UpdatePolicy.isTransientLaunch(installPath: "/private/tmp/NepalKit.app"))
        #expect(UpdatePolicy.isTransientLaunch(installPath: "/Volumes/NepalKit-release-check/NepalKit.app"))
        #expect(UpdatePolicy.isTransientLaunch(installPath: "/Users/dev/Library/Developer/Xcode/DerivedData/NepalKit-abc/Build/Products/Debug/NepalKit.app"))
        #expect(!UpdatePolicy.isTransientLaunch(installPath: "/Applications/NepalKit.app"))
        #expect(!UpdatePolicy.isTransientLaunch(installPath: "/Applications/NepalKit.app/Contents/MacOS/NepalKit"))
    }

    @Test func aPathMerelyContainingTmpIsNotTransient() {
        #expect(!UpdatePolicy.isTransientLaunch(installPath: "/Applications/tmp-tests/NepalKit.app"))
    }

    @Test func noUpdateFoundClassifiesByReason() {
        #expect(UpdatePolicy.outcome(forNoUpdateFound: .onLatestVersion, failureReason: "x") == .upToDate)
        #expect(UpdatePolicy.outcome(forNoUpdateFound: .onNewerThanLatestVersion, failureReason: "x") == .upToDate)
        #expect(UpdatePolicy.outcome(forNoUpdateFound: .other, failureReason: "feed unreachable")
            == .failed(reason: "feed unreachable"))
    }
}
