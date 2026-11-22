// swift-tools-version: 6.2
// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Dibas Sigdel
import PackageDescription

let package = Package(
    name: "NepalKitWatchSupport",
    platforms: [.macOS(.v26), .watchOS(.v26)],
    products: [
        .library(name: "NepalKitWatchSupport", targets: ["NepalKitWatchSupport"]),
    ],
    dependencies: [
        .package(path: "../NepalKitCore"),
    ],
    targets: [
        .target(
            name: "NepalKitWatchSupport",
            dependencies: [.product(name: "NepalKitCore", package: "NepalKitCore")]
        ),
        .testTarget(
            name: "NepalKitWatchSupportTests",
            dependencies: [
                "NepalKitWatchSupport",
                .product(name: "NepalKitCore", package: "NepalKitCore"),
            ]
        ),
    ]
)
