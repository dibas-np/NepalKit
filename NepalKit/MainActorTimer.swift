// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Dibas Sigdel
import Foundation

/// Schedules a timer on the main run loop whose block runs on the main actor.
///
/// Call only from the main actor. Added in the common run-loop modes so the timer
/// keeps firing while a menu is tracking.
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
