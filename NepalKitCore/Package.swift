// swift-tools-version: 6.2
// 6.2 rather than 6.0 because `Platform.macOS(.v26)` — the floor this package
// now declares — does not exist in a 6.0 manifest. The app-test harness is on
// the same tools version for the same reason.
import PackageDescription

let package = Package(
    name: "NepalKitCore",
    // Matches the app's deployment floor (ADR-0003) and, since the Watch app
    // arrived, the Watch products' watchOS 26.0 floor. Without these the
    // package inherits the toolchain's default target, which is *lower* than
    // the app's, so a macOS 27-only API in the core would compile cleanly
    // here and only fail on the floor. Declaring them makes the core honest
    // about the floors it has to run on, and keeps this manifest agreeing
    // with the app-test harness, which already pins `.macOS(.v26)`.
    platforms: [.macOS(.v26), .watchOS(.v26)],
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
