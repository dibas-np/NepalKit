// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "NepalKitAppTests",
    platforms: [.macOS(.v26)],
    products: [
        .library(name: "NepalKit", targets: ["NepalKit"]),
    ],
    dependencies: [
        .package(path: "../../NepalKitCore"),
    ],
    targets: [
        .target(
            name: "NepalKit",
            dependencies: [.product(name: "NepalKitCore", package: "NepalKitCore")],
            exclude: [
                "NepalKitApp.swift",
                "Assets.xcassets",
                "Info.plist",
                "NepalKit.entitlements",
                "SparkleUpdateService.swift",
            ],
            swiftSettings: [
                .defaultIsolation(MainActor.self),
                .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
                .enableUpcomingFeature("InferIsolatedConformances"),
                .enableUpcomingFeature("MemberImportVisibility"),
            ]
        ),
        .testTarget(
            name: "NepalKitTests",
            dependencies: [
                "NepalKit",
                .product(name: "NepalKitCore", package: "NepalKitCore"),
            ],
            swiftSettings: [
                .defaultIsolation(MainActor.self),
                .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
                .enableUpcomingFeature("InferIsolatedConformances"),
            ]
        ),
    ]
)
