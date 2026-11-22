// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Dibas Sigdel
import Foundation

/// The update path's decisions, kept out of `SparkleUpdateService.swift` so the
/// app-test harness can compile and test them.
enum UpdatePolicy {
    /// A build directory or mounted image, where an in-place self-update cannot succeed.
    static func isTransientLaunch(installPath: String) -> Bool {
        installPath.hasPrefix("/tmp/")
            || installPath.hasPrefix("/private/tmp/")
            || installPath.hasPrefix("/Volumes/")
            || installPath.contains("/DerivedData/")
    }

    /// Being current is a good answer; not being able to find out is not.
    enum NoUpdateFoundKind {
        case onLatestVersion
        case onNewerThanLatestVersion
        case other
    }

    static func outcome(forNoUpdateFound kind: NoUpdateFoundKind, failureReason: String) -> UpdateOutcome {
        switch kind {
        case .onLatestVersion, .onNewerThanLatestVersion: return .upToDate
        case .other: return .failed(reason: failureReason)
        }
    }

    /// Only scheduled checks on a transient launch are refused; manual checks run.
    static func vetoesCheck(isScheduled: Bool, installPath: String) -> Bool {
        isScheduled && isTransientLaunch(installPath: installPath)
    }

    /// Classified by raw value: an `NSNumber` held in `Any` does not cast to an
    /// imported `NS_ENUM`, so casting would treat "on the latest version" as a failure.
    static func noUpdateKind(rawReason: Int?) -> NoUpdateFoundKind {
        switch rawReason {
        case 1: .onLatestVersion            // SPUNoUpdateFoundReasonOnLatestVersion
        case 2: .onNewerThanLatestVersion   // SPUNoUpdateFoundReasonOnNewerThanLatestVersion
        default: .other                     // unknown (0), OS too old (3) / too new (4), no ARM64 (5), or absent
        }
    }

    /// `nil` for "no update" and user cancellation, which are reported elsewhere.
    static func outcome(forAbortedCheckDomain domain: String, code: Int, description: String) -> UpdateOutcome? {
        if domain == "SUSparkleErrorDomain" && (code == 1001 || code == 4007) {
            // SUNoUpdateError, SUInstallationCanceledError
            return nil
        }
        return .failed(reason: description)
    }
}
