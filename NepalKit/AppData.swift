// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Dibas Sigdel
import Foundation
import NepalKitCore

enum AppData {
    nonisolated static let dataset = CalendarDataset.v2
}

#if DEBUG
extension AppData {
    nonisolated static let previewInstant = Date(timeIntervalSince1970: 1_792_272_000)
}
#endif
