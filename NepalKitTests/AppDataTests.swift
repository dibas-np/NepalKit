// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Dibas Sigdel
import Testing
import NepalKitCore
@testable import NepalKit

struct AppDataTests {
    @Test func theAppConvertsWithTheNewestBundledDataset() {
        #expect(AppData.dataset.version == CalendarDataset.v2.version)
        #expect(AppData.dataset.supportedRange == CalendarDataset.v2.supportedRange)
    }
}
