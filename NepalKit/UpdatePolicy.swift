// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Dibas Sigdel
import Foundation

/// The update path's decisions, kept out of `SparkleUpdateService.swift` so
/// the app-test harness can compile them: that file imports Sparkle and is
/// excluded from the harness (scripts/apptests/Package.swift), and an
/// untestable decision is one a refactor can silently invert. The Sparkle
/// file maps framework types onto the neutral inputs these functions take;
/// everything after that mapping is pinned by `UpdatePolicyTests`.
enum UpdatePolicy {
    /// Whether a launch from this bundle path is transient — a build directory
    /// or a mounted image, where an in-place self-update cannot succeed. The
    /// prefixes match `start()`'s measured failures (2026-09-28): /tmp debug
    /// copies, DMG mounts, and DerivedData builds.
    static func isTransientLaunch(installPath: String) -> Bool {
        installPath.hasPrefix("/tmp/")
            || installPath.hasPrefix("/private/tmp/")
            || installPath.hasPrefix("/Volumes/")
            || installPath.contains("/DerivedData/")
    }

    /// How the framework's "no update found" reason classifies, per
    /// `UpdateOutcome`'s contract: being current is a good answer; not being
    /// able to find out is not. The Sparkle delegate reduces the framework's
    /// reason enum to this kind, so the decision lives here where it is
    /// testable.
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

    /// Whether a check should be refused: only a scheduled check on a transient
    /// launch, where the self-update cannot succeed. A manual check is the user
    /// asking a question, so it still runs.
    static func vetoesCheck(isScheduled: Bool, installPath: String) -> Bool {
        isScheduled && isTransientLaunch(installPath: installPath)
    }

    /// Classifies Sparkle's `SPUNoUpdateFoundReason` by raw value. The framework
    /// stores an `NSNumber` under `SPUNoUpdateFoundReasonKey`, and an `NSNumber`
    /// held in `Any` does not cast to an imported `NS_ENUM`: casting to the enum
    /// classifies every "on the latest version" result as a failure.
    static func noUpdateKind(rawReason: Int?) -> NoUpdateFoundKind {
        switch rawReason {
        case 1: .onLatestVersion            // SPUNoUpdateFoundReasonOnLatestVersion
        case 2: .onNewerThanLatestVersion   // SPUNoUpdateFoundReasonOnNewerThanLatestVersion
        default: .other                     // unknown (0), OS too old (3) / too new (4), no ARM64 (5), or absent
        }
    }

    /// What an aborted update cycle means to the user. `nil` means "say
    /// nothing": "no update" and user cancellation also arrive here and are
    /// answered elsewhere. Any other abort is a check that did not complete.
    static func outcome(forAbortedCheckDomain domain: String, code: Int, description: String) -> UpdateOutcome? {
        if domain == "SUSparkleErrorDomain" && (code == 1001 || code == 4007) {
            // SUNoUpdateError, SUInstallationCanceledError
            return nil
        }
        return .failed(reason: description)
    }
}
