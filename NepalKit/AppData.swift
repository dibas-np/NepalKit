// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Dibas Sigdel
import NepalKitCore

/// The dataset the app converts with, named once.
///
/// Every model, scene body, and preview reads this constant; no other file
/// names a `CalendarDataset.v*` literal. Bumping the dataset (ADR-0002:
/// a new bundled table per release) then means changing this line — and the
/// rename of the core constant it points at, per ADR-0010's rule that an
/// identifier must not lie about the range it names — instead of grepping
/// nine sites and hoping.
enum AppData {
    // `nonisolated` because the project compiles with a default isolation of
    // MainActor, which would otherwise isolate this to the main actor. Every
    // model exposes the dataset as a default argument, and default arguments
    // are evaluated outside the callee's isolation, so an isolated constant
    // makes each of those declarations a concurrency warning.
    nonisolated static let dataset = CalendarDataset.v2
}
