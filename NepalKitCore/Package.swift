// swift-tools-version: 6.2
// 6.2 rather than 6.0 to match the app-test harness and the Watch support
// package, which need it for `.macOS(.v26)`.
import PackageDescription

let package = Package(
    name: "NepalKitCore",
    // The lowest floors the current Xcode builds for; it raises anything lower
    // without a word. Declaring them keeps availability honest: an API newer
    // than a floor fails to compile here rather than in an app that uses the
    // package. The suite runs on the newest macOS, iOS and watchOS before each
    // release (scripts/release-core.sh). tvOS and visionOS are compile-checked
    // only.
    //
    // The watchOS floor must not be higher than the Watch app's, which
    // scripts/verify-deployment-floor.py checks.
    platforms: [.macOS(.v12), .iOS(.v15), .watchOS(.v9), .tvOS(.v15), .visionOS(.v1)],
    products: [
        .library(name: "NepalKitCore", targets: ["NepalKitCore"]),
    ],
    targets: [
        .target(
            name: "NepalKitCore",
            resources: [.copy("Resources/AskBuddie-LICENSE.txt")]
        ),
        .testTarget(
            name: "NepalKitCoreTests",
            dependencies: ["NepalKitCore"]
        ),
    ]
)
