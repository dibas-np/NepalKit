// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Dibas Sigdel
import Testing
@testable import NepalKit

/// The automatic-checks toggle's binding on `UpdateCheckModel`, apart from the
/// model's other tests to keep that file under the length limit.
@MainActor
struct UpdateCheckSettingTests {
    @Test func theToggleBindingReadsTheCopyAndWritesThroughTheService() {
        let service = FakeUpdateService()
        let model = UpdateCheckModel(service: service)
        model.automaticChecksSetting = false
        #expect(service.automaticallyChecksForUpdates == false)
        #expect(model.automaticChecksSetting == false && model.automaticallyChecks == false)
        model.automaticChecksSetting = true
        #expect(service.automaticallyChecksForUpdates == true)
    }
}
