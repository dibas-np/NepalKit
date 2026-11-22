// SPDX-License-Identifier: GPL-3.0-or-later
import Foundation
import Testing
@testable import NepalKit

/// Checks the built app's Info.plist. `INFOPLIST_KEY_*` silently drops keys
/// outside Apple's allowlist, so these read the product, not the project.
/// Skipped when no built product is available.
struct InfoPlistKeysTests {
    nonisolated private static let appBundleIdentifier = "com.dibas.NepalKit.NepalKit"

    /// The built app's Info.plist: `NEPAKIT_BUILT_PLIST` if set, otherwise the
    /// host app's bundle. Only a plist naming the app's bundle identifier
    /// counts, since under SwiftPM `Bundle.main` is the test runner.
    nonisolated private static let builtPlist: URL? = resolvedPlist.url

    /// True when `NEPAKIT_BUILT_PLIST` names no readable Info.plist for the app.
    nonisolated private static let overrideWasUnusable: Bool = resolvedPlist.overrideWasUnusable

    nonisolated private static let resolvedPlist: (url: URL?, overrideWasUnusable: Bool) = {
        func usable(_ url: URL) -> URL? {
            guard let info = NSDictionary(contentsOf: url) as? [String: Any],
                  info["CFBundleIdentifier"] as? String == appBundleIdentifier
            else { return nil }
            return url
        }

        if let override = ProcessInfo.processInfo.environment["NEPAKIT_BUILT_PLIST"], !override.isEmpty {
            let url = usable(URL(fileURLWithPath: override))
            return (url, url == nil)
        }
        return (usable(Bundle.main.bundleURL.appendingPathComponent("Contents/Info.plist")), false)
    }()

    nonisolated private static var builtInfo: [String: Any]? {
        guard let builtPlist else { return nil }
        return NSDictionary(contentsOf: builtPlist) as? [String: Any]
    }

    /// Searched upward because `#filePath` may be the symlinked harness path.
    private static var repositoryRoot: URL {
        var dir = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        for _ in 0 ..< 8 {
            if FileManager.default.fileExists(atPath: dir.appendingPathComponent("NepalKit.xcodeproj").path) {
                return dir
            }
            dir = dir.deletingLastPathComponent()
        }
        Issue.record("could not locate the repository root from #filePath")
        return URL(fileURLWithPath: "/")
    }

    /// The public key release artifacts are signed with.
    private static let expectedPublicKey = "HJ/gD4l4Ojf8vILqA+81fO7U327vcxXEipVA5PICZQA="

    /// Without a build the product checks are skipped rather than failed.
    nonisolated private static var hasBuiltProduct: Bool { builtInfo != nil }

    @Test func anExplicitBuiltProductMustBeReadable() {
        // Skipping is for when nothing was built. A named product that can't be
        // read would otherwise turn the release-key checks into silent skips.
        #expect(!Self.overrideWasUnusable,
                "NEPAKIT_BUILT_PLIST is set but names no readable Info.plist for \(Self.appBundleIdentifier)")
    }

    @Test(.enabled(if: hasBuiltProduct, "no built product to check — run a build first"))
    func sparklePublicKeyReachesTheBuiltProduct() throws {
        let info = try #require(Self.builtInfo)

        #expect(
            info["SUPublicEDKey"] as? String == Self.expectedPublicKey,
            "the built app cannot verify updates: SUPublicEDKey is \(info["SUPublicEDKey"].map { "\"\($0)\"" } ?? "absent")"
        )
    }

    @Test(.enabled(if: hasBuiltProduct, "no built product to check — run a build first"))
    func thePlistIsAuthoritativeInTheBuiltProduct() throws {
        // Version keys arrive substituted from build settings.
        let info = try #require(Self.builtInfo)

        #expect(info["LSUIElement"] as? Bool == true, "menu-bar-only would be lost")
        #expect(info["CFBundleIdentifier"] as? String == "com.dibas.NepalKit.NepalKit")
        #expect(info["SUEnableInstallerLauncherService"] as? Bool == true,
                "sandboxed installs abort at the installer launch without it")
        #expect(info["CFBundleShortVersionString"] is String, "the human-facing version is substituted")
        #expect(info["CFBundleVersion"] is String, "the build number the updater orders on is substituted")
        #expect(info["CFBundleIconName"] as? String == "AppIcon", "the icon would fall back to a generic one")
        #expect(info["LSApplicationCategoryType"] as? String == "public.app-category.utilities", "the category clears a build warning only if it arrives")
        #expect(info["LSMinimumSystemVersion"] is String, "the deployment floor must be stated in the product")
    }

    @Test(.enabled(if: hasBuiltProduct, "no built product to check — run a build first"))
    func feedURLIsStableHTTPSAndAbsolute() throws {
        // A feed URL that moves strands every existing installation.
        let info = try #require(Self.builtInfo)
        let feed = try #require(info["SUFeedURL"] as? String, "SUFeedURL is absent")

        #expect(feed == Self.expectedFeedURL, "feed URL changed: \(feed)")
        #expect(feed.hasPrefix("https://"), "Sparkle refuses an insecure feed")
        #expect(URL(string: feed)?.host == "dibas-np.github.io", "feed is not served from this repository")
    }

    @Test(.enabled(if: hasBuiltProduct, "no built product to check — run a build first"))
    func theSignedFeedIsRequiredInTheBuiltProduct() throws {
        // Being able to verify isn't enough: unless a signature is required, a
        // feed stripped of it in transit is read happily.
        let info = try #require(Self.builtInfo)
        let value = info["SURequireSignedFeed"].map { "\($0)" } ?? "absent"

        #expect(info["SURequireSignedFeed"] as? Bool == true,
                "the built app reads an unsigned feed unauthenticated: SURequireSignedFeed is \(value)")
    }

    @Test(.enabled(if: hasBuiltProduct, "no built product to check — run a build first"))
    func updatesAreVerifiedBeforeExtractionInTheBuiltProduct() throws {
        // Sparkle refuses to check for updates at all when SURequireSignedFeed
        // is on and this is off.
        let info = try #require(Self.builtInfo)
        let value = info["SUVerifyUpdateBeforeExtraction"].map { "\($0)" } ?? "absent"

        #expect(info["SUVerifyUpdateBeforeExtraction"] as? Bool == true,
                "the updater cannot check for updates at all: SUVerifyUpdateBeforeExtraction is \(value)")
    }

    /// Every installed copy reads this URL; changing it breaks all their updates.
    private static let expectedFeedURL = "https://dibas-np.github.io/NepalKit/appcast.xml"

    @Test(.enabled(if: hasBuiltProduct, "no built product to check — run a build first"))
    func theCopyrightLineReachesTheBuiltProduct() throws {
        let info = try #require(Self.builtInfo)
        let copyright = try #require(info["NSHumanReadableCopyright"] as? String, "copyright line is absent")

        #expect(copyright == "Copyright (C) 2026 Dibas Sigdel")

        // A source header must name the same rights holder as the app.
        let appSources = try FileManager.default.contentsOfDirectory(atPath: Self.repositoryRoot.appendingPathComponent("NepalKit").path)
            .filter { $0.hasSuffix(".swift") }
        #expect(!appSources.isEmpty, "no app sources found beside the project")

        let headers = try appSources.map { filename in
            try String(contentsOf: Self.repositoryRoot
                .appendingPathComponent("NepalKit/\(filename)"), encoding: .utf8)
        }
        #expect(headers.contains { $0.contains(copyright) },
                "the About surfaces and the source headers state different holders")
        #expect(headers.contains { $0.contains("SPDX-License-Identifier: GPL-3.0-or-later") },
                "no source header carries the licence identifier")
    }

    @Test(.enabled(if: hasBuiltProduct, "no built product to check — run a build first"))
    func theLicenceTravelsWithTheBinary() throws {
        // GPL-3.0 requires the licence to accompany the binary.
        let bundle = try #require(Self.builtPlist)
            .deletingLastPathComponent()
            .deletingLastPathComponent()   // NepalKit.app
        let shipped = bundle.appendingPathComponent("Contents/Resources/LICENSE")
        #expect(FileManager.default.fileExists(atPath: shipped.path), "the app ships without its licence")

        let text = try String(contentsOf: shipped, encoding: .utf8)
        #expect(text.contains("GNU GENERAL PUBLIC LICENSE"))
        #expect(text.contains("Version 3, 29 June 2007"))
        // A real licence, not a stub that merely names one.
        #expect(text.contains("TERMS AND CONDITIONS"))
        #expect(text.contains("END OF TERMS AND CONDITIONS"))

        // Anything prepended stops GitHub's Licensee from identifying it. The
        // canonical file indents its title, so compare the trimmed first line.
        let firstNonEmptyLine = text
            .split(whereSeparator: \.isNewline)
            .first { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
            .map { $0.trimmingCharacters(in: .whitespaces) }
        #expect(firstNonEmptyLine == "GNU GENERAL PUBLIC LICENSE",
                "something is prepended to LICENSE, so GitHub cannot identify the licence; first line is \(firstNonEmptyLine.map { "\"\($0)\"" } ?? "absent")")
    }

    @Test func thePublicKeyIsWellFormed() {
        // 32 bytes, base64 — the shape Ed25519 requires. A truncated paste would
        // still commit cleanly and fail only at update time.
        let raw = Data(base64Encoded: Self.expectedPublicKey)

        #expect(raw != nil, "public key is not valid base64")
        #expect(raw?.count == 32, "public key is \(raw?.count ?? -1) bytes, expected 32")
    }
}
