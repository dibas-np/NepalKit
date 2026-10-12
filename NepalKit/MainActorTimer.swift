// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Dibas Sigdel
import Foundation

/// Schedules a timer on the main run loop whose block runs on the main actor.
///
/// `Timer.scheduledTimer`'s block is plain `@Sendable`, so every clock-like
/// model would otherwise repeat the `MainActor.assumeIsolated` hop at its own
/// call site. The hop is sound because this is only ever called from
/// main-actor contexts, which is also what puts the timer on the main run loop.
///
/// Added in the common modes rather than the default one that
/// `Timer.scheduledTimer` uses: the default mode does not run while a menu is
/// tracking, so a clock would freeze for as long as a menu stays open.
func scheduledMainActorTimer(
    withTimeInterval interval: TimeInterval,
    repeats: Bool,
    _ update: @escaping @MainActor () -> Void
) -> Timer {
    let timer = Timer(timeInterval: interval, repeats: repeats) { _ in
        MainActor.assumeIsolated {
            update()
        }
    }
    RunLoop.main.add(timer, forMode: .common)
    return timer
}
