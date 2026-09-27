// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "NepalKitCore",
    products: [
        .library(name: "NepalKitCore", targets: ["NepalKitCore"]),
    ],
    targets: [
        .target(name: "NepalKitCore"),
        .testTarget(
            name: "NepalKitCoreTests",
            dependencies: ["NepalKitCore"]
        ),
    ]
)
