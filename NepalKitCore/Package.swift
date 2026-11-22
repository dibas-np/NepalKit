// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "NepalKitCore",
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
