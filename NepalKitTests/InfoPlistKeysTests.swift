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
    func theGeneratedKeysSurviveThePlistMerge() throws {
        // Wiring INFOPLIST_FILE alongside GENERATE_INFOPLIST_FILE merges the
        // two. If that merge ever stopped happening, NepalKit would silently
        // become a Dock app — the single most visible regression available to
        // this change — and the build would still be green.
        let info = try #require(Self.builtInfo)

        #expect(info["LSUIElement"] as? Bool == true, "menu-bar-only would be lost")
        #expect(info["CFBundleIdentifier"] as? String == "com.dibas.NepalKit.NepalKit")
        #expect(info["CFBundleShortVersionString"] as? String != nil, "the human-facing version is generated")
        #expect(info["CFBundleVersion"] as? String != nil, "the build number the updater orders on is generated")
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

    @Test func thePublicKeyIsWellFormed() {
        // 32 bytes, base64 — the shape Ed25519 requires. A truncated paste would
        // still commit cleanly and fail only at update time.
        let raw = Data(base64Encoded: Self.expectedPublicKey)

        #expect(raw != nil, "public key is not valid base64")
        #expect(raw?.count == 32, "public key is \(raw?.count ?? -1) bytes, expected 32")
    }
}
