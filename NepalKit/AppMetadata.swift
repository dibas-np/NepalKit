// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Dibas Sigdel
import AppKit

/// Facts about the installed build, read from its own bundle.
///
/// About exists so a user can say what they are running and report it. That only
/// works if every value on it comes from the build that is actually running, so
/// nothing here is a literal: name, versions, icon and repository all come from
/// the bundle, and the calendar facts come from the dataset (ADR-0009 treats the
/// three version numbers as independent; this type is where two of them live).
///
/// Injectable rather than reading `Bundle.main` directly, so tests can supply a
/// dictionary and prove the surface reads metadata instead of hardcoding it.
struct AppMetadata: Equatable {
    /// The source repository, as a single named constant rather than a literal
    /// in a view.
    ///
    /// It is *not* an `INFOPLIST_KEY_` build setting, though that is where it
    /// belongs conceptually. The project generates its Info.plist, and Xcode
    /// honours only a known allowlist of `INFOPLIST_KEY_*` names — an unknown
    /// one is dropped in silence, leaving no key and no diagnostic. Carrying it
    /// here is the honest option until the project ships a real Info.plist.
    ///
    /// Kept in step with `git remote origin`. If the repository moves, this
    /// constant, the README, and the release script that reads it
    /// (scripts/verify-appcast.sh) are the places that follow.
    static let defaultRepositoryURL = URL(string: "https://github.com/dibas-np/NepalKit")!

    let name: String
    /// `CFBundleShortVersionString` — the human-facing version.
    let shortVersion: String
    /// `CFBundleVersion` — monotonically increasing, and what Sparkle orders on.
    let buildNumber: String
    /// The source repository, for the one interactive element on the surface.
    let repositoryURL: URL?
    /// `NSHumanReadableCopyright`. Empty until the rights-holder question is
    /// answered in writing, which the release contract says must happen before
    /// any public metadata is finalised. The surface omits the line entirely
    /// rather than rendering a blank, so the field appears by itself the moment
    /// the build setting is filled in.
    let copyright: String?
    let applicationIcon: NSImage?
    /// The licence the shipped bundle actually contains, read from the bundled
    /// `LICENSE` rather than asserted in a string.
    ///
    /// This exists because a licence name in About is a legal claim, and a
    /// literal one silently outlives whatever it claimed. Reading the file means
    /// the surface cannot name MIT while shipping GPL text. The identifier shown
    /// is derived from the document's own title line, and the file ships in the
    /// bundle as a resource, so this is the shipped artefact and not a copy of it.
    let license: String?

    init(
        info: [String: Any] = Bundle.main.infoDictionary ?? [:],
        repositoryURL: URL? = AppMetadata.defaultRepositoryURL,
        applicationIcon: NSImage? = nil
    ) {
        name = (info["CFBundleName"] as? String) ?? ""
        shortVersion = (info["CFBundleShortVersionString"] as? String) ?? ""
        buildNumber = (info["CFBundleVersion"] as? String) ?? ""
        self.repositoryURL = repositoryURL
        let declared = (info["NSHumanReadableCopyright"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
        copyright = (declared?.isEmpty ?? true) ? nil : declared
        self.applicationIcon = applicationIcon
        license = AppMetadata.licenseIdentifier(in: Bundle.main.resourceURL)
    }

    /// Name and version of the licence in a bundle's `LICENSE`, or nil.
    ///
    /// Parsed from the document's own heading (`GNU GENERAL PUBLIC LICENSE` /
    /// `Version 3`) rather than matched against a list of known licences: a
    /// literal table here would be a second place for the licence to be wrong.
    ///
    /// Non-optional parameter for the directory so a test can point at a
    /// fixture instead of whichever bundle happens to be loaded.
    static func licenseIdentifier(in resourceURL: URL?) -> String? {
        guard let resourceURL else { return nil }
        let text = try? String(contentsOf: resourceURL.appendingPathComponent("LICENSE"), encoding: .utf8)
        guard let heading = text?.split(separator: "\n").prefix(8).joined(separator: "\n"),
              let name = Self.licenseName(in: heading),
              !name.isEmpty else { return nil }
        // The version is the token immediately after "Version". Taking the last
        // token instead reads "Version 3, 29 June 2007" as 2007, which is the
        // year the document was published rather than the licence version.
        let versionLine = heading.split(separator: "\n").first { $0.contains("Version") }
        let versionNumber = versionLine.flatMap { line -> Substring? in
            let tokens = line.split(separator: " ")
            guard let marker = tokens.firstIndex(of: "Version") else { return nil }
            let next = tokens.index(after: marker)
            return next < tokens.endIndex ? tokens[next] : nil
        }
        let version = versionNumber
            .map { " \($0.trimmingCharacters(in: CharacterSet(charactersIn: " ,")))" } ?? ""
        return name + version
    }

    /// The licence's own name from the head of its text, or nil if absent.
    ///
    /// An MIT licence has no `Version` line, and its body is the copyright line
    /// first, so the version-bearing shape this file is written for does not
    /// apply. Matching on `LICENSE` alone would return "MIT License" from the
    /// body of any file, so the name is only taken from a line that is
    /// *predominantly* the title: no "Copyright", no colon, not a sentence.
    private static func licenseName(in heading: String) -> String? {
        heading.split(separator: "\n")
            .lazy
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .first { line in
                let upper = line.uppercased()
                return upper.contains("LICENSE")
                    && !upper.contains("VERSION")
                    && !line.contains("Copyright")
                    && !line.contains(":")
                    && line.count <= 64
            }
    }

    /// The installed build's own facts, including its real app icon.
    @MainActor
    static func current() -> AppMetadata {
        AppMetadata(applicationIcon: NSApp.applicationIconImage)
    }

    /// Apple's own About-panel form: human-facing version, then the build in
    /// parentheses so a bug report can name the exact build.
    var versionDescription: String {
        shortVersion.isEmpty ? buildNumber : "\(shortVersion) (\(buildNumber))"
    }
}
