// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Dibas Sigdel
import AppKit

/// Facts about the installed build, read from its bundle rather than hardcoded.
struct AppMetadata: Equatable {
    /// Not an `INFOPLIST_KEY_` build setting: Xcode silently drops unknown keys.
    /// Keep in step with the README and scripts/verify-appcast.sh.
    static let defaultRepositoryURL = URL(string: "https://github.com/dibas-np/NepalKit")!

    let name: String
    /// `CFBundleShortVersionString`.
    let shortVersion: String
    /// `CFBundleVersion`, which Sparkle orders on.
    let buildNumber: String
    let repositoryURL: URL?
    /// `NSHumanReadableCopyright`, or nil when absent or blank.
    let copyright: String?
    let applicationIcon: NSImage?
    /// The licence name read from the bundled `LICENSE`, so About can't disagree with it.
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
    static func licenseIdentifier(in resourceURL: URL?) -> String? {
        guard let resourceURL else { return nil }
        let text = try? String(contentsOf: resourceURL.appendingPathComponent("LICENSE"), encoding: .utf8)
        guard let heading = text?.split(separator: "\n").prefix(8).joined(separator: "\n"),
              let name = Self.licenseName(in: heading),
              !name.isEmpty else { return nil }
        // The token after "Version"; the last token of "Version 3, 29 June 2007" is a year.
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

    /// The licence's title line: mentions LICENSE but isn't a copyright line or a
    /// sentence, so an MIT body line isn't mistaken for it.
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

    @MainActor
    static func current() -> AppMetadata {
        AppMetadata(applicationIcon: NSApp.applicationIconImage)
    }

    /// "1.2 (45)", as Apple's About panel shows it.
    var versionDescription: String {
        shortVersion.isEmpty ? buildNumber : "\(shortVersion) (\(buildNumber))"
    }
}
