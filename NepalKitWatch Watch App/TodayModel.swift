// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Dibas Sigdel
import Foundation
import NepalKitCore

/// Resolves the Watch's read-only Today state from one instant read per
/// operation. The clock is injected so tests pin the instant; production owns
/// the one function that reads wall time, and no view ever resolves a date.
///
/// This is the seed of the Today lifecycle model: launch/activation handling,
/// the active-midnight refresh and clock-change observation arrive with the
/// Today ticket; this scaffold only proves the shared core and dataset answer
/// in a Watch target context.
@MainActor
@Observable
final class TodayModel {
    private let now: @Sendable () -> Date

    /// The rendered Today line, or the range-boundary statement when the
    /// current NPT day lies outside the dataset's supported range. Calculation
    /// failures become their own distinct state with the display/speech
    /// tickets; the scaffold renders both boundary and failure through the
    /// shared firm copy until then.
    private(set) var displayText: String

    init(now: @escaping @Sendable () -> Date = { Date.now }) {
        self.now = now
        self.displayText = ""
    }

    /// Reads the clock once and resolves Today through the shared core.
    func refresh() {
        let instant = now()
        if let bs = todayBS(now: instant, in: .v2) {
            displayText = formatBS(bs, settings: .watch)
        } else {
            displayText = "Bikram Sambat unavailable"
        }
    }
}
