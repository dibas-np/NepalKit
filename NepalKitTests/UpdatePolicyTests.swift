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

    @Test func onlyAScheduledCheckIsVetoedOnATransientLaunch() {
        let transient = "/Users/dev/Library/Developer/Xcode/DerivedData/NepalKit-abc/Build/Products/Debug/NepalKit.app"
        #expect(UpdatePolicy.vetoesCheck(isScheduled: true, installPath: transient))
        #expect(!UpdatePolicy.vetoesCheck(isScheduled: false, installPath: transient))
        #expect(!UpdatePolicy.vetoesCheck(isScheduled: true, installPath: "/Applications/NepalKit.app"))
        #expect(!UpdatePolicy.vetoesCheck(isScheduled: false, installPath: "/Applications/NepalKit.app"))
    }

    @Test func noUpdateFoundClassifiesByTheFrameworksRawReason() {
        // SPUNoUpdateFoundReason raw values, SUErrors.h in Sparkle 2.10.0.
        #expect(UpdatePolicy.outcome(forNoUpdateReason: 1, failureReason: "x") == .upToDate)
        #expect(UpdatePolicy.outcome(forNoUpdateReason: 2, failureReason: "x") == .upToDate)
        #expect(UpdatePolicy.outcome(forNoUpdateReason: 0, failureReason: "feed unreachable")
            == .failed(reason: "feed unreachable"))
        #expect(UpdatePolicy.outcome(forNoUpdateReason: 3, failureReason: "x") == .failed(reason: "x"))
        #expect(UpdatePolicy.outcome(forNoUpdateReason: nil, failureReason: "x") == .failed(reason: "x"))
    }

    @Test func anAbortedCheckIsAFailureUnlessTheFrameworkAlreadyAnsweredIt() {
        #expect(UpdatePolicy.outcome(forAbortedCheckDomain: "SUSparkleErrorDomain", code: 1001, description: "x") == nil)
        #expect(UpdatePolicy.outcome(forAbortedCheckDomain: "SUSparkleErrorDomain", code: 4007, description: "x") == nil)
        #expect(UpdatePolicy.outcome(forAbortedCheckDomain: "SUSparkleErrorDomain", code: 1002, description: "feed unreachable")
            == .failed(reason: "feed unreachable"))
        #expect(UpdatePolicy.outcome(forAbortedCheckDomain: "NSURLErrorDomain", code: -1009, description: "offline")
            == .failed(reason: "offline"))
        #expect(UpdatePolicy.outcome(forAbortedCheckDomain: "NepalKit.Update", code: 1, description: "skipped")
            == .failed(reason: "skipped"))
    }
}
