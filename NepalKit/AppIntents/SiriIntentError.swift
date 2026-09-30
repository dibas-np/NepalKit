// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Dibas Sigdel
import AppIntents

/// A thrown intent failure carrying the exact dialog the failure wording
/// requires (ticket 03). Whether each macOS surface actually shows a thrown
/// error's message rather than a generic one is prototype checklist item 5 —
/// that is precisely what this type exists to observe.
nonisolated struct SiriIntentError: Error, LocalizedError, CustomLocalizedStringResourceConvertible {
    let dialog: LocalizedStringResource

    var errorDescription: String? { String(localized: dialog) }

    var localizedStringResource: LocalizedStringResource { dialog }
}
