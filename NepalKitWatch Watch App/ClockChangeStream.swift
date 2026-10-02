// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Dibas Sigdel
import Foundation
import NepalKitCore

/// The system clock-change stream the Today model consumes while active.
///
/// Production bridges the Foundation system-clock-change notification — the
/// documented interoperating partner of `Date.SystemClockDidChangeMessage`
/// (watchOS 26). The message type itself has no async-sequence consumption
/// path (`NotificationCenter.messages(of:)` requires `AsyncMessage`), so the
/// notification bridged through a `Sendable` stream is the concurrency-safe
/// adapter the handoff calls for. Tests inject their own stream and drive
/// forward/backward changes deterministically.
typealias ClockChangeStream = AsyncStream<Void>

extension NotificationCenter {
    /// Bridges the system clock-change notification into a stream. The
    /// observer is removed when the stream terminates — including when the
    /// consuming task is cancelled — so ownership follows the lifecycle.
    ///
    /// The observer token is immutable and `removeObserver` is thread-safe,
    /// so sharing it with the termination closure is sound even though
    /// `NSObjectProtocol` carries no `Sendable` promise. `nonisolated`
    /// because the injected clock-change closure must be `@Sendable`.
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
