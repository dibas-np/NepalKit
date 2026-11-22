// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Dibas Sigdel
import Foundation
import NepalKitCore

/// System clock changes, as a stream. `Date.SystemClockDidChangeMessage` is not
/// an `AsyncMessage`, so this bridges the older notification instead.
typealias ClockChangeStream = AsyncStream<Void>

extension NotificationCenter {
    /// The observer is removed when the stream terminates. The token is
    /// immutable and `removeObserver` is thread-safe, hence `nonisolated(unsafe)`.
    nonisolated func systemClockChangeStream() -> ClockChangeStream {
        return AsyncStream { continuation in
            nonisolated(unsafe) let token = addObserver(forName: .NSSystemClockDidChange, object: nil, queue: nil) { _ in
                continuation.yield()
            }
            continuation.onTermination = { _ in
                NotificationCenter.default.removeObserver(token)
            }
        }
    }
}
