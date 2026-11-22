// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Dibas Sigdel
import Foundation

typealias ClockChangeStream = AsyncStream<Void>

extension NotificationCenter {
    nonisolated func systemClockChangeStream() -> ClockChangeStream {
        return AsyncStream { continuation in
            nonisolated(unsafe) let token = addObserver(forName: .NSSystemClockDidChange, object: nil, queue: nil) { _ in
                continuation.yield()
            }
            continuation.onTermination = { [center = self] _ in
                center.removeObserver(token)
            }
        }
    }
}
