// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "NepalKitCore",
    // The lowest floors the current Xcode builds for. The watchOS floor must not
    // exceed the Watch app's (checked by scripts/verify-deployment-floor.py).
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
