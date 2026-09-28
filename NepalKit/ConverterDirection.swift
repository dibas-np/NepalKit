// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Dibas Sigdel

/// Direction of conversion. The toggle preserves the converted date so the
/// user never re-enters anything.
enum ConverterDirection: Hashable {
    case bsToAD
    case adToBS
}
