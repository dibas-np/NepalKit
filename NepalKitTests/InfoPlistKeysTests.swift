// SPDX-License-Identifier: GPL-3.0-or-later
import Foundation
import Testing
@testable import NepalKit

/// The built Info.plist, when a build is available.
///
/// This exists because of a demonstrated, silent failure. `INFOPLIST_KEY_*`
/// honours only a fixed allowlist of Apple-known names, and a name outside it is
/// **accepted by the build and discarded with no warning**: setting
/// `INFOPLIST_KEY_SUPublicEDKey` produced a successful build and an app with no
/// `SUPublicEDKey` in it at all. A shipped app in that state could not verify a
/// single update, and the only evidence anything was wrong was a green build.
///
/// So these tests read the product, not the project. When no build is present
/// they are skipped rather than passed, because a test that cannot check
/// something must not report that it did.
struct InfoPlistKeysTests {
    /// Where `scripts/run-app-tests.sh` and the CI build both put the product.
    /// Overridable so a build in another location can still be checked.
    private static let builtPlist = URL(fileURLWithPath: ProcessInfo.processInfo.environment["NEPAKIT_BUILT_PLIST"] ?? "")
    private static var builtInfo: [String: Any]? {
        guard FileManager.default.fileExists(atPath: builtPlist.path) else { return nil }
        return NSDictionary(contentsOf: builtPlist) as? [String: Any]
    }

    /// The repository root, found by walking up from this file.
    ///
    /// Not a fixed number of `deletingLastPathComponent` calls: the harness
    /// compiles these tests through a symlink, so `#filePath` may name either
    /// `NepalKitTests/` or `scripts/apptests/Tests/NepalKitTests/`, and a depth
    /// that works for one is wrong for the other. Walking up to a file that
    /// only exists at the root is correct either way.
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

    /// The key the release artifacts are signed with. Committed deliberately:
    /// it is public, and it is what lets an installed copy verify a download.
    private static let expectedPublicKey = "HJ/gD4l4Ojf8vILqA+81fO7U327vcxXEipVA5PICZQA="

    /// Checks the built product rather than the project settings, so a value
    /// the build discards cannot pass. Gated on a build existing: with none,
    /// the test is *skipped with a reason* rather than failed, because "cannot
    /// check" is not "the key is missing" and conflating them would make the gate
    /// useless the first time someone runs the harness without building.
    /// The trait's comment must be a compile-time literal, so the path cannot
    /// appear in it; the test name and the skip reason carry the meaning.
    private static var hasBuiltProduct: Bool { builtInfo != nil }

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
        // The plist states every key itself now (GENERATE_INFOPLIST_FILE is
        // off), so there is no merge to survive — but the keys still have to
        // reach the product intact, and the version keys still arrive
        // substituted from build settings (ADR-0009). Losing LSUIElement would
        // silently turn NepalKit into a Dock app — the single most visible
        // regression available to this change — and the build would stay green.
        let info = try #require(Self.builtInfo)

        #expect(info["LSUIElement"] as? Bool == true, "menu-bar-only would be lost")
        #expect(info["CFBundleIdentifier"] as? String == "com.dibas.NepalKit.NepalKit")
        #expect(info["SUEnableInstallerLauncherService"] as? Bool == true,
                "sandboxed installs abort at the installer launch without it")
        #expect(info["CFBundleShortVersionString"] as? String != nil, "the human-facing version is substituted")
        #expect(info["CFBundleVersion"] as? String != nil, "the build number the updater orders on is substituted")
        #expect(info["CFBundleIconName"] as? String == "AppIcon", "the icon would fall back to a generic one")
        #expect(info["LSApplicationCategoryType"] as? String == "public.app-category.utilities", "the category clears a build warning only if it arrives")
        #expect(info["LSMinimumSystemVersion"] as? String != nil, "the deployment floor must be stated in the product")
    }

    @Test(.enabled(if: hasBuiltProduct, "no built product to check — run a build first"))
    func feedURLIsStableHTTPSAndAbsolute() throws {
        // A feed URL that moves strands every existing installation, so the
        // shape is pinned: HTTPS (Sparkle refuses insecure feeds), absolute, and
        // served from this repository rather than a host that could vanish.
        let info = try #require(Self.builtInfo)
        let feed = try #require(info["SUFeedURL"] as? String, "SUFeedURL is absent")

        #expect(feed == Self.expectedFeedURL, "feed URL changed: \(feed)")
        #expect(feed.hasPrefix("https://"), "Sparkle refuses an insecure feed")
        #expect(URL(string: feed)?.host == "dibas-np.github.io", "feed is not served from this repository")
    }

    /// The feed's declared home. Changing it is a release decision: every
    /// installed copy reads this URL, so a change breaks updates for all of them
    /// at once.
    private static let expectedFeedURL = "https://dibas-np.github.io/NepalKit/appcast.xml"

    @Test(.enabled(if: hasBuiltProduct, "no built product to check — run a build first"))
    func theCopyrightLineReachesTheBuiltProduct() throws {
        // The About surfaces render NSHumanReadableCopyright, and the value is
        // only correct if it survives the plist merge. Set through INFOPLIST_KEY_
        // it could be dropped silently, with a green build — the exact failure
        // documented at the top of Info.plist. Checked against the built product.
        let info = try #require(Self.builtInfo)
        let copyright = try #require(info["NSHumanReadableCopyright"] as? String, "copyright line is absent")

        #expect(copyright == "Copyright (C) 2026 Dibas Sigdel")

        // It must match what the source files declare, or the app and the
        // repository name different holders.
        //
        // This used to be checked against LICENSE, which is where the notice was
        // originally. That arrangement was wrong: a project notice prepended to
        // LICENSE stops GitHub's Licensee identifying the licence, and GitHub
        // reported the repository as NOASSERTION. The GPL's own guidance puts
        // the notice in the source headers and leaves LICENSE as the licence
        // text alone, which is what this now checks.
        let source = Self.repositoryRoot.appendingPathComponent("NepalKit/PopoverView.swift")
        let header = try String(contentsOf: source, encoding: .utf8)

        #expect(header.contains(copyright),
                "the About surfaces and the source headers state different holders")
        #expect(header.contains("SPDX-License-Identifier: GPL-3.0-or-later"))
    }

    @Test(.enabled(if: hasBuiltProduct, "no built product to check — run a build first"))
    func theLicenceTravelsWithTheBinary() throws {
        // GPL-3.0 requires the licence to accompany the work, not just to sit in
        // the repository. For a distributed .app that means inside the bundle:
        // a user who has the binary has to be able to read what they may do
        // with it, offline, without a network round trip to the source.
        //
        // Checked in the built product, because the interesting failure is a
        // resource build phase that quietly stopped copying the file.
        let bundle = Self.builtPlist.deletingLastPathComponent()
            .deletingLastPathComponent()   // NepalKit.app
        let shipped = bundle.appendingPathComponent("Contents/Resources/LICENSE")
        #expect(FileManager.default.fileExists(atPath: shipped.path), "the app ships without its licence")

        let text = try String(contentsOf: shipped, encoding: .utf8)
        #expect(text.contains("GNU GENERAL PUBLIC LICENSE"))
        #expect(text.contains("Version 3, 29 June 2007"))
        // A real licence, not a stub that merely names one.
        #expect(text.contains("TERMS AND CONDITIONS"))
        #expect(text.contains("END OF TERMS AND CONDITIONS"))

        // It must be the licence and nothing else. Anything prepended — a project
        // notice, a README extract — stops GitHub's Licensee from identifying
        // it, and the repository then shows NOASSERTION: this project was
        // published that way until this assertion existed. The GPL asks for the
        // notice in the source headers, not in the licence file.
        //
        // Compared as the first non-empty line, trimmed of its own indentation.
        // The canonical file indents the title by 20 spaces, so trimming the
        // whole text and then asserting a prefix *containing* that indentation
        // could never pass — the original form of this assertion was provably
        // dead and only went unnoticed because it is gated on a built product.
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
