// swift-tools-version: 6.2
// 6.2 rather than 6.0 because `Platform.macOS(.v26)` — the floor this package
// now declares — does not exist in a 6.0 manifest. The app-test harness is on
// the same tools version for the same reason.
import PackageDescription

let package = Package(
    name: "NepalKitCore",
    // Matches the app's deployment floor (ADR-0003) and, since the Watch app
    // arrived, the Watch products' watchOS floor. Without these the
    // package inherits the toolchain's default target, which is *lower* than
    // the app's, so a macOS 27-only API in the core would compile cleanly
    // here and only fail on the floor. Declaring them makes the core honest
    // about the floors it has to run on, and keeps this manifest agreeing
    // with the app-test harness, which already pins `.macOS(.v26)`.
    //
    // The watchOS case below stays as it is and must not be "corrected" to
    // match the app's 26.6, for two separate reasons:
    //
    // 1. It is not expressible. A watchOS platform case for 26.6, and one for 27,
    //    are both rejected outright while the manifest is compiled ("failed to
    //    produce diagnostic for expression"); the manifest API's watchOS versions
    //    are discrete cases, not arbitrary versions. Measured, not assumed.
    // 2. It is not the same claim. This platform is the *library's* compile
    //    floor - the core calendar logic genuinely runs on the older floor. The
    //    app's watchOS deployment target is a *product* claim about the oldest
    //    supported watch, and the two are allowed to differ as long as this one
    //    is not *higher* than the product's. So the relation the gate enforces
    //    is `<=`, never `==`; the package must not require more than its
    //    consumer, while the consumer may require more than the library.
    //
    // scripts/verify-deployment-floor.py is what checks that relation, alongside
    // every watchOS block in the Xcode project having to agree with itself.
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
