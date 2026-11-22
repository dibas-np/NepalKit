// swift-tools-version: 6.2
// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Dibas Sigdel
//
// Display helpers shared by the Watch app and its complication extension.
// Kept out of NepalKitCore, which is published for other apps.
import PackageDescription

let package = Package(
    name: "NepalKitWatchSupport",
    // The Watch products' floor, plus macOS so `swift test` runs on the Mac.
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
