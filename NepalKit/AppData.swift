// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Dibas Sigdel
import Foundation
import NepalKitCore

/// The dataset the app converts with. The only place that names a
/// `CalendarDataset.v*` constant.
enum AppData {
    // `nonisolated` because the target defaults to MainActor isolation, and models
    // use this as a default argument, which is evaluated outside that isolation.
    nonisolated static let dataset = CalendarDataset.v2
}

#if DEBUG
extension AppData {
    /// Fixed instant for previews: 2026-10-18 03:05 Nepal Time, a Sunday in range.
    nonisolated static let previewInstant = Date(timeIntervalSince1970: 1_792_272_000)
}
#endif
