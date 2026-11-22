// swift-tools-version: 6.2
// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Dibas Sigdel
//
// The Watch's shared display meaning: what the Watch app and its complication
// extension both render and announce. The two watchOS products cannot share a
// framework target and neither can see the other's files, so the helpers they
// must agree on byte for byte live here, linked by both. Outside NepalKitCore
// on purpose: that directory is published as a package for other apps, and
// none of this is meant for them.
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
