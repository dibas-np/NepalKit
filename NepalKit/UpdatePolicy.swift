// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Dibas Sigdel
import Foundation

enum UpdatePolicy {
    static func isTransientLaunch(installPath: String) -> Bool {
        installPath.hasPrefix("/tmp/")
            || installPath.hasPrefix("/private/tmp/")
            || installPath.hasPrefix("/Volumes/")
            || installPath.contains("/DerivedData/")
    }

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

    static func vetoesCheck(isScheduled: Bool, installPath: String) -> Bool {
        isScheduled && isTransientLaunch(installPath: installPath)
    }

    /// Classified by raw value: an `NSNumber` held in `Any` does not cast to an
    /// imported `NS_ENUM`, so casting would treat "on the latest version" as a failure.
    static func noUpdateKind(rawReason: Int?) -> NoUpdateFoundKind {
        switch rawReason {
        case 1: .onLatestVersion
        case 2: .onNewerThanLatestVersion
        default: .other
        }
    }

    static func outcome(forAbortedCheckDomain domain: String, code: Int, description: String) -> UpdateOutcome? {
        if domain == "SUSparkleErrorDomain" && (code == 1001 || code == 4007) {
            return nil
        }
        return .failed(reason: description)
    }
}
