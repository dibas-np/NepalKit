// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Dibas Sigdel
import AppKit

struct AppMetadata: Equatable {
    static let repositoryURL = URL(string: "https://github.com/dibas-np/NepalKit")!

    let name: String
    let shortVersion: String
    let buildNumber: String
    let applicationIcon: NSImage?

    init(
        info: [String: Any] = Bundle.main.infoDictionary ?? [:],
        applicationIcon: NSImage? = nil
    ) {
        name = (info["CFBundleName"] as? String) ?? ""
        shortVersion = (info["CFBundleShortVersionString"] as? String) ?? ""
        buildNumber = (info["CFBundleVersion"] as? String) ?? ""
        self.applicationIcon = applicationIcon
    }

    @MainActor
    static func current() -> AppMetadata {
        AppMetadata(applicationIcon: NSApp.applicationIconImage)
    }

    var versionDescription: String {
        shortVersion.isEmpty ? buildNumber : "\(shortVersion) (\(buildNumber))"
    }
}
