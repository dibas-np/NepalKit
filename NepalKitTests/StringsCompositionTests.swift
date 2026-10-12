// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Dibas Sigdel
import Testing
@testable import NepalKit

/// The `Strings` functions that compose a sentence around a value the caller
/// supplies, so the wording around the value is pinned.
struct StringsCompositionTests {
    @Test func versionAndLastCheckedFrameTheirValues() {
        #expect(Strings.versionLabel("1.2.3") == "Version 1.2.3")
        #expect(Strings.updateLastChecked("11 Oct 2026") == "Last checked: 11 Oct 2026")
    }

    @Test func loginItemFailureNamesTheDirectionAndQuotesTheReason() {
        #expect(
            Strings.loginItemFailureReason(.registration("denied"))
                == "Could not change launch at login (turning it on). The system reported: \u{201C}denied\u{201D}"
        )
        #expect(
            Strings.loginItemFailureReason(.deregistration("busy"))
                == "Could not change launch at login (turning it off). The system reported: \u{201C}busy\u{201D}"
        )
    }
}
