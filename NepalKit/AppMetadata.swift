// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Dibas Sigdel
import AppKit

struct AppMetadata: Equatable {
    static let defaultRepositoryURL = URL(string: "https://github.com/dibas-np/NepalKit")!

    let name: String
    let shortVersion: String
    let buildNumber: String
    let repositoryURL: URL?
    let copyright: String?
    let applicationIcon: NSImage?
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

    static func licenseIdentifier(in resourceURL: URL?) -> String? {
        guard let resourceURL else { return nil }
        let text = try? String(contentsOf: resourceURL.appendingPathComponent("LICENSE"), encoding: .utf8)
        guard let heading = text?.split(separator: "\n").prefix(8).joined(separator: "\n"),
              let name = Self.licenseName(in: heading),
              !name.isEmpty else { return nil }
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

    var versionDescription: String {
        shortVersion.isEmpty ? buildNumber : "\(shortVersion) (\(buildNumber))"
    }
}
