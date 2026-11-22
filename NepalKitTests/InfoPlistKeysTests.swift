// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Dibas Sigdel
import Foundation
import Testing
@testable import NepalKit

struct InfoPlistKeysTests {
    nonisolated private static let appBundleIdentifier = "com.dibas.NepalKit.NepalKit"

    /// Only a plist naming the app's bundle identifier counts, since under
    /// SwiftPM `Bundle.main` is the test runner.
    nonisolated private static let builtPlist: URL? = resolvedPlist.url

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

    private static let expectedPublicKey = "HJ/gD4l4Ojf8vILqA+81fO7U327vcxXEipVA5PICZQA="

    nonisolated private static var hasBuiltProduct: Bool { builtInfo != nil }

    @Test func anExplicitBuiltProductMustBeReadable() {
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
        let info = try #require(Self.builtInfo)

        #expect(info["LSUIElement"] as? Bool == true, "menu-bar-only would be lost")
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
        // Sparkle falls back to an unverified feed after this interval; zero disables that.
        #expect((info["SUSignedFeedFailureExpirationInterval"] as? NSNumber)?.doubleValue == 0,
                "the built app trusts a failing feed after a grace period")
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

    private static let expectedFeedURL = "https://dibas-np.github.io/NepalKit/appcast.xml"

    @Test(.enabled(if: hasBuiltProduct, "no built product to check — run a build first"))
    func theCopyrightLineReachesTheBuiltProduct() throws {
        let info = try #require(Self.builtInfo)
        let copyright = try #require(info["NSHumanReadableCopyright"] as? String, "copyright line is absent")

        #expect(copyright == "Copyright (C) 2026 Dibas Sigdel")

        let appSources = try FileManager.default.contentsOfDirectory(atPath: Repository.root.appendingPathComponent("NepalKit").path)
            .filter { $0.hasSuffix(".swift") }
        #expect(!appSources.isEmpty, "no app sources found beside the project")

        let headers = try appSources.map { filename in
            try String(contentsOf: Repository.root
                .appendingPathComponent("NepalKit/\(filename)"), encoding: .utf8)
        }
        #expect(headers.contains { $0.contains(copyright) },
                "the About surfaces and the source headers state different holders")
        #expect(headers.contains { $0.contains("SPDX-License-Identifier: GPL-3.0-or-later") },
                "no source header carries the licence identifier")
    }

    @Test(.enabled(if: hasBuiltProduct, "no built product to check — run a build first"))
    func theLicenceTravelsWithTheBinary() throws {
        let bundle = try #require(Self.builtPlist)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let shipped = bundle.appendingPathComponent("Contents/Resources/LICENSE")
        #expect(FileManager.default.fileExists(atPath: shipped.path), "the app ships without its licence")

        let text = try String(contentsOf: shipped, encoding: .utf8)
        #expect(text.contains("GNU GENERAL PUBLIC LICENSE"))
        #expect(text.contains("Version 3, 29 June 2007"))
        #expect(text.contains("TERMS AND CONDITIONS"))
        #expect(text.contains("END OF TERMS AND CONDITIONS"))

        let firstNonEmptyLine = text
            .split(whereSeparator: \.isNewline)
            .first { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
            .map { $0.trimmingCharacters(in: .whitespaces) }
        #expect(firstNonEmptyLine == "GNU GENERAL PUBLIC LICENSE",
                "something is prepended to LICENSE, so GitHub cannot identify the licence; first line is \(firstNonEmptyLine.map { "\"\($0)\"" } ?? "absent")")
    }

    @Test func thePublicKeyIsWellFormed() {
        let raw = Data(base64Encoded: Self.expectedPublicKey)

        #expect(raw != nil, "public key is not valid base64")
        #expect(raw?.count == 32, "public key is \(raw?.count ?? -1) bytes, expected 32")
    }
}
