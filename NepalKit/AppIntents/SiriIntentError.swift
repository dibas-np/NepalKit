// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Dibas Sigdel
import AppIntents

nonisolated struct SiriIntentError: Error, LocalizedError, CustomLocalizedStringResourceConvertible {
    let dialog: LocalizedStringResource

    var errorDescription: String? { String(localized: dialog) }

    var localizedStringResource: LocalizedStringResource { dialog }
}
