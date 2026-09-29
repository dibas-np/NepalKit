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
}
