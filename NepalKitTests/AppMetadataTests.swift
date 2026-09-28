// SPDX-License-Identifier: GPL-3.0-or-later
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

      /// Walked up from this file rather than assumed, so the test does not
      /// depend on the working directory the runner happens to use.
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

      /// Writes `text` as a LICENSE in a fresh temporary directory and returns it.
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
          // The reason this is parsed rather than hardcoded: a licence name in
          // About is a legal claim. A literal cannot be wrong visibly, so a
          // project relicensed MIT would keep shipping "GPL-3.0" in About with
          // every test still green.
          let shipped = try #require(
              AppMetadata.licenseIdentifier(in: Self.repositoryRoot),
              "the repository's own LICENSE did not parse"
          )
          #expect(shipped == "GNU GENERAL PUBLIC LICENSE 3")
      }

      @Test func licenceVersionIsTheVersionNotThePublicationYear() throws {
          // The heading is "Version 3, 29 June 2007". Taking the last token
          // yields 2007 — the year the FSF published it, presented to the user
          // as the licence version. Caught by reading the parsed value rather
          // than by testing the tokenisation in isolation.
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
          // An MIT licence has no "Version" line at all, and its body opens with
          // a copyright line. If the parser required the version-bearing shape
          // it would return nil, and About would silently omit the licence for
          // any project that ever switched. Pinning this also proves the parser
          // is reading the file rather than hardcoding the current answer: it
          // reports MIT when handed MIT, and GPL-3 when handed the GPL.
          let directory = try licenseDirectory("MIT License\n\nCopyright (c) 2026 Someone\n")
          defer { try? FileManager.default.removeItem(at: directory) }
          #expect(AppMetadata.licenseIdentifier(in: directory) == "MIT License")
      }

      @Test func anAbsentLicenceIsNilRatherThanAPlaceholder() {
          // About omits the row entirely when this is nil, rather than
          // rendering a blank or a dash. Guessing a licence for a bundle that
          // has none would be the exact failure this design avoids.
          #expect(AppMetadata.licenseIdentifier(in: nil) == nil)
          #expect(AppMetadata.licenseIdentifier(in: URL(fileURLWithPath: "/nonexistent")) == nil)
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
