// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Dibas Sigdel

/// Direction of conversion. The toggle preserves the converted date so the
/// user never re-enters anything.
enum ConverterDirection: Hashable {
    case bsToAD
    case adToBS

    /// The direction after a toggle. The one place that maps a direction to
    /// its opposite, so no call site grows its own.
    var swapped: ConverterDirection {
        switch self {
        case .bsToAD: .adToBS
        case .adToBS: .bsToAD
        }
    }
}
