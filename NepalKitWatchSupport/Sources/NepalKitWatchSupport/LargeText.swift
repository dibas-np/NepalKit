// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Dibas Sigdel
import SwiftUI

/// The watchOS Text Size slider stops below the accessibility sizes, so
/// `isAccessibilitySize` never fires.
extension DynamicTypeSize {
    public var watchLargeTextFallback: Bool {
        self >= .xxLarge
    }
}
