// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Dibas Sigdel
import Foundation
import Testing
import NepalKitCore
import NepalKitWatchSupport

struct WatchCoreSmokeTests {
    @Test func watchContextRendersTheFixedCanonicalSettings() throws {
        let now = try UTCWatchFixture.utc(2026, 9, 26, 18, 30)

        #expect(BikramSambatDate.today(now: now, in: .v2).map { ($0).formatted(.watch) } == "११ असोज २०८३")
    }
}
