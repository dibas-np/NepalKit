// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Dibas Sigdel
import Foundation
import Testing
@testable import NepalKit

@MainActor
struct AppMetadataTests {
    private func info(
        name: String = "NepalKit",
        short: String = "1.0",
        build: String = "42"
    ) -> [String: Any] {
        [
            "CFBundleName": name,
            "CFBundleShortVersionString": short,
            "CFBundleVersion": build,
        ]
    }

    @Test func readsNameAndBothVersionNumbersFromTheBundle() {
        let metadata = AppMetadata(info: info(short: "1.0", build: "42"), applicationIcon: nil)

        #expect(metadata.name == "NepalKit")
        #expect(metadata.shortVersion == "1.0")
        #expect(metadata.buildNumber == "42")
    }

    @Test func versionDescriptionCarriesBothNumbers() {
        let metadata = AppMetadata(info: info(short: "0.9.1", build: "137"), applicationIcon: nil)

        #expect(metadata.versionDescription == "0.9.1 (137)")
    }

    @Test func repositoryURLIsTheProjectsOwnRemote() {
        #expect(AppMetadata.repositoryURL.absoluteString == "https://github.com/dibas-np/NepalKit")
    }

    @Test func missingKeysDoNotProduceEmptyPresentedText() {
        let metadata = AppMetadata(info: [:], applicationIcon: nil)

        #expect(metadata.name.isEmpty)
        #expect(metadata.versionDescription.isEmpty)
    }
}
