import Foundation
import NepalKitCore
import Testing
@testable import NepalKit

/// About is only useful if it can be trusted to describe the running build, so
/// these tests pin where each value comes from rather than what it happens to
/// say today. A literal in the view would make every one of them fail.
@MainActor
struct AppMetadataTests {
    private func info(
        name: String = "NepalKit",
        short: String = "1.0",
        build: String = "42",
        copyright: String = ""
    ) -> [String: Any] {
        [
            "CFBundleName": name,
            "CFBundleShortVersionString": short,
            "CFBundleVersion": build,
            "NSHumanReadableCopyright": copyright,
        ]
    }

    @Test func readsNameAndBothVersionNumbersFromTheBundle() {
        let metadata = AppMetadata(info: info(short: "1.0", build: "42"), applicationIcon: nil)

        #expect(metadata.name == "NepalKit")
        #expect(metadata.shortVersion == "1.0")
        #expect(metadata.buildNumber == "42")
    }

    @Test func versionDescriptionCarriesBothNumbers() {
        // ADR-0009: the short version is what a human quotes, the build number
        // is what a bug report needs. Apple's own panels show both.
        let metadata = AppMetadata(info: info(short: "0.9.1", build: "137"), applicationIcon: nil)

        #expect(metadata.versionDescription == "0.9.1 (137)")
    }

    @Test func repositoryURLIsTheProjectsOwnRemote() {
        // A repository link that points somewhere else is worse than none: it
        // looks like a working destination and is not. Asserted against the
        // real remote so a repository move cannot pass unnoticed.
        let metadata = AppMetadata(info: info(), applicationIcon: nil)

        #expect(metadata.repositoryURL?.absoluteString == "https://github.com/dibas-np/NepalKit")
    }

    @Test func absentRepositoryYieldsNoLinkRatherThanABrokenOne() {
        let metadata = AppMetadata(info: info(), repositoryURL: nil, applicationIcon: nil)

        #expect(metadata.repositoryURL == nil)
    }

    @Test func emptyCopyrightBecomesNoLineAtAll() {
        // The rights holder is unresolved and the release contract says no
        // public metadata is finalised before it is answered. An empty string
        // must not reach the surface as a blank line.
        let metadata = AppMetadata(info: info(copyright: ""), applicationIcon: nil)

        #expect(metadata.copyright == nil)
    }

    @Test func whitespaceOnlyCopyrightAlsoBecomesNoLine() {
        let metadata = AppMetadata(info: info(copyright: "   \n "), applicationIcon: nil)

        #expect(metadata.copyright == nil)
    }

    @Test func settledCopyrightHolderAppears() {
        // When the rights-holder track resolves, filling the build setting is
        // the only change needed — the line is already wired.
        let metadata = AppMetadata(
            info: info(copyright: "Copyright © 2026 Finnove Technologies"),
            applicationIcon: nil
        )

        #expect(metadata.copyright == "Copyright © 2026 Finnove Technologies")
    }

    @Test func missingKeysDoNotProduceEmptyPresentedText() {
        let metadata = AppMetadata(info: [:], repositoryURL: nil, applicationIcon: nil)

        #expect(metadata.name.isEmpty)
        #expect(metadata.versionDescription.isEmpty)
        #expect(metadata.copyright == nil)
        #expect(metadata.repositoryURL == nil)
    }

    // MARK: - The calendar facts belong to the dataset

    @Test func datasetVersionAndRangeComeFromTheDataset() {
        // Ticket 03 narrowed the range and bumped the dataset version. If About
        // carried a literal for either, the next dataset release would make it
        // stale with nothing failing.
        #expect(CalendarDataset.v2.version == "2.0.0")
        #expect(CalendarDataset.v2.supportedRange == 1975 ... 2084)
    }
}
