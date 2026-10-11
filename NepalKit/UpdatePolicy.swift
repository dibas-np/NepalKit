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

    /// Whether a check should be refused. Only a *scheduled* check is refused,
    /// and only on a transient launch: a scheduled self-update from a build
    /// directory or a mounted image cannot succeed, while a manual check is the
    /// user asking a question that is still worth answering. The direction of
    /// this rule was inverted in the adapter for a while, and no gate could see
    /// it because the adapter is outside the harness; this function is what
    /// makes the direction testable.
    static func vetoesCheck(isScheduled: Bool, installPath: String) -> Bool {
        isScheduled && isTransientLaunch(installPath: installPath)
    }

    /// The raw values of Sparkle's `SPUNoUpdateFoundReason`, as the framework
    /// stores them: it puts an `NSNumber` under `SPUNoUpdateFoundReasonKey` and
    /// reads it back with `integerValue`. The numbers are the contract, not the
    /// imported enum: an `NSNumber` held in `Any` does not cast to an imported
    /// `NS_ENUM`, which is how every "on the latest version" result was once
    /// classified as a failure.
    static func noUpdateKind(rawReason: Int?) -> NoUpdateFoundKind {
        switch rawReason {
        case 1: .onLatestVersion            // SPUNoUpdateFoundReasonOnLatestVersion
        case 2: .onNewerThanLatestVersion   // SPUNoUpdateFoundReasonOnNewerThanLatestVersion
        default: .other                     // unknown (0), OS too old (3) / too new (4), no ARM64 (5), or absent
        }
    }

    /// What an aborted update cycle means to the user. `nil` means "say
    /// nothing": the framework reports "no update" and a user cancellation
    /// through this path too, and both are already answered elsewhere. Every
    /// other abort is a check that did not complete, which must never read as
    /// "up to date".
    static func outcome(forAbortedCheckDomain domain: String, code: Int, description: String) -> UpdateOutcome? {
        if domain == "SUSparkleErrorDomain" && (code == 1001 || code == 4007) {
            // SUNoUpdateError, SUInstallationCanceledError
            return nil
        }
        return .failed(reason: description)
    }
}
