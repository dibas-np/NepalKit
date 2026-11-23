// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Dibas Sigdel
#if canImport(Sparkle)
import Foundation
import Sparkle
import Testing
@testable import NepalKit

@MainActor
struct SparkleFeedURLTests {
    @Test func aLaunchArgumentCannotRepointTheFeed() throws {
        let defaults = UserDefaults.standard
        let saved = defaults.volatileDomain(forName: UserDefaults.argumentDomain)
        defaults.setVolatileDomain(saved.merging(["SUFeedURL": "https://example.invalid/appcast.xml"]) { $1 },
                                   forName: UserDefaults.argumentDomain)
        defer { defaults.setVolatileDomain(saved, forName: UserDefaults.argumentDomain) }
        let service = SparkleUpdateService()
        let updater = SPUUpdater(hostBundle: .main, applicationBundle: .main,
                                 userDriver: SPUStandardUserDriver(hostBundle: .main, delegate: nil),
                                 delegate: service)
        #expect(defaults.string(forKey: "SUFeedURL") == "https://example.invalid/appcast.xml")
        #expect(updater.feedURL?.absoluteString == "https://dibas-np.github.io/NepalKit/appcast.xml")
    }
}
#endif
