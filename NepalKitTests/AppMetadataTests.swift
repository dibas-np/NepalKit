// SPDX-License-Identifier: GPL-3.0-or-later
import Foundation
import NepalKitCore
import Testing
@testable import NepalKit

/// Pins where each About value comes from, so About describes the running build.
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
        // About shows both the short version and the build number.
        let metadata = AppMetadata(info: info(short: "0.9.1", build: "137"), applicationIcon: nil)

        #expect(metadata.versionDescription == "0.9.1 (137)")
    }

    @Test func repositoryURLIsTheProjectsOwnRemote() {
        // A link that points somewhere else is worse than none.
        let metadata = AppMetadata(info: info(), applicationIcon: nil)

        #expect(metadata.repositoryURL?.absoluteString == "https://github.com/dibas-np/NepalKit")
    }

    @Test func absentRepositoryYieldsNoLinkRatherThanABrokenOne() {
        let metadata = AppMetadata(info: info(), repositoryURL: nil, applicationIcon: nil)

        #expect(metadata.repositoryURL == nil)
    }

    @Test func emptyCopyrightBecomesNoLineAtAll() {
        // An empty string must not reach the surface as a blank line.
        let metadata = AppMetadata(info: info(copyright: ""), applicationIcon: nil)

        #expect(metadata.copyright == nil)
    }

    @Test func whitespaceOnlyCopyrightAlsoBecomesNoLine() {
        let metadata = AppMetadata(info: info(copyright: "   \n "), applicationIcon: nil)

        #expect(metadata.copyright == nil)
    }

    @Test func settledCopyrightHolderAppears() {
        let metadata = AppMetadata(
            info: info(copyright: "Copyright (C) 2026 Dibas Sigdel"),
            applicationIcon: nil
        )

        #expect(metadata.copyright == "Copyright (C) 2026 Dibas Sigdel")
    }

    @Test func missingKeysDoNotProduceEmptyPresentedText() {
        let metadata = AppMetadata(info: [:], repositoryURL: nil, applicationIcon: nil)

        #expect(metadata.name.isEmpty)
        #expect(metadata.versionDescription.isEmpty)
        #expect(metadata.copyright == nil)
        #expect(metadata.repositoryURL == nil)
    }

    // MARK: - The licence is read, not asserted

    private static var repositoryRoot: URL {
        var dir = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        for _ in 0 ..< 8 {
            if FileManager.default.fileExists(atPath: dir.appendingPathComponent("NepalKit.xcodeproj").path) {
                return dir
            }
            dir = dir.deletingLastPathComponent()
        }
        return URL(fileURLWithPath: #filePath).deletingLastPathComponent()
    }

    private func licenseDirectory(_ text: String) throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("nk-lic-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try text.write(
            to: directory.appendingPathComponent("LICENSE"), atomically: true, encoding: .utf8
        )
        return directory
    }

    @Test func licenceComesFromTheShippedFileNotFromAString() throws {
        // A licence name in About is a legal claim, so it is read from the file.
        let shipped = try #require(
            AppMetadata.licenseIdentifier(in: Self.repositoryRoot),
            "the repository's own LICENSE did not parse"
        )
        #expect(shipped == "GNU GENERAL PUBLIC LICENSE 3")
    }

    @Test func licenceVersionIsTheVersionNotThePublicationYear() throws {
        // The heading is "Version 3, 29 June 2007"; its last token is the
        // publication year, not the version.
        let directory = try licenseDirectory(
            """
            GNU GENERAL PUBLIC LICENSE
               Version 3, 29 June 2007
            """
        )
        defer { try? FileManager.default.removeItem(at: directory) }
        #expect(AppMetadata.licenseIdentifier(in: directory) == "GNU GENERAL PUBLIC LICENSE 3")
    }

    @Test func licenceWithoutAVersionLineStillNamesItself() throws {
        // An MIT licence has no "Version" line and opens with a copyright line.
        let directory = try licenseDirectory("MIT License\n\nCopyright (c) 2026 Someone\n")
        defer { try? FileManager.default.removeItem(at: directory) }
        #expect(AppMetadata.licenseIdentifier(in: directory) == "MIT License")
    }

    @Test func anAbsentLicenceIsNilRatherThanAPlaceholder() {
        // About omits the row when this is nil.
        #expect(AppMetadata.licenseIdentifier(in: nil) == nil)
        #expect(AppMetadata.licenseIdentifier(in: URL(fileURLWithPath: "/nonexistent")) == nil)
    }

    // MARK: - The calendar facts belong to the dataset

    @Test func datasetVersionAndRangeComeFromTheDataset() {
        // A literal in About would go stale with the next dataset release.
        #expect(CalendarDataset.v2.version == "2.0.1")
        #expect(CalendarDataset.v2.supportedRange == 1975 ... 2084)
    }
}
