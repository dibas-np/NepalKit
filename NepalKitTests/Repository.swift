// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Dibas Sigdel
import Foundation

enum Repository {
    /// The checkout root, found by walking up from this file to `NepalKit.xcodeproj`.
    nonisolated static var root: URL {
        var directory = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        while directory.path != "/" {
            if FileManager.default.fileExists(atPath: directory.appending(path: "NepalKit.xcodeproj").path) {
                return directory
            }
            directory.deleteLastPathComponent()
        }
        return directory
    }

    nonisolated static func file(_ relativePath: String) -> URL {
        root.appending(path: relativePath)
    }
}
