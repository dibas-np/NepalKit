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
    static let dataset = CalendarDataset.v2
}
