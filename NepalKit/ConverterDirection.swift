// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Dibas Sigdel

/// Direction of conversion.
enum ConverterDirection: Hashable {
    case bsToAD
    case adToBS

    var swapped: ConverterDirection {
        switch self {
        case .bsToAD: .adToBS
        case .adToBS: .bsToAD
        }
    }
}
