// swift-tools-version: 6.2
//
// App-layer test harness.
//
// `xcodebuild test` builds NepalKit clean but the test runner hangs before
// connecting in this environment, so the app-layer suite runs here instead
// (see docs/adr/0005-app-layer-test-execution.md).
//
// Both target directories are symlinks to the real `NepalKit/` and
// `NepalKitTests/` directories, so the harness compiles the actual app
// sources and the real test files, unmodified. Earlier revisions of this
// harness held *copies* and rewrote `@testable import NepalKit` to
// `@testable import Harness` in each test file. That per-file edit is what let
// the copies silently drift: they predated the menu-bar midnight timer and the
// hardened converter clamping, so they were not testing current code. Naming
// the target `NepalKit` and symlinking removes both the copies and the edits.
//
// Run with scripts/run-app-tests.sh, which is the single documented invocation.
import PackageDescription

let package = Package(
    name: "NepalKitAppTests",
    // Matches the app's real deployment floor (ADR-0003), so the harness is a
    // faithful compile check rather than a laxer one. Anything the app can build
    // at macOS 26, this can build.
    platforms: [.macOS(.v26)],
    products: [
        .library(name: "NepalKit", targets: ["NepalKit"]),
    ],
    dependencies: [
        // Relative, so a fresh clone anywhere resolves.
        .package(path: "../../NepalKitCore"),
    ],
    targets: [
        .target(
            name: "NepalKit",
            dependencies: [.product(name: "NepalKitCore", package: "NepalKitCore")],
            // NepalKitApp.swift owns @main, which a library target cannot have.
            // Assets.xcassets, Info.plist, and NepalKit.entitlements belong to
            // the Xcode app bundle, not here.
            exclude: [
                "NepalKitApp.swift",
                "Assets.xcassets",
                "Info.plist",
                "NepalKit.entitlements",
                // Imports Sparkle; the harness links only NepalKitCore. The
                // seam it implements is Sparkle-free and fully covered here.
                "SparkleUpdateService.swift",
            ]
        ),
        .testTarget(
            name: "NepalKitTests",
            dependencies: [
                "NepalKit",
                .product(name: "NepalKitCore", package: "NepalKitCore"),
            ]
        ),
    ]
)
