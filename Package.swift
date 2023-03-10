// swift-tools-version: 5.7
// The swift tools-version declares the minimum version of Swift required to build this package.

// *************** Not complete yet, do not expect this to work! ***********************
// There are issues with how test fixtures are copied into the bundle, and then referenced,
// and other issues, largely around accessing bundle resources, and probably others not yet
// discovered, as this is not being used as a swift package from any actual project yet.

import PackageDescription

let package = Package(
    name: "LoopKit",
    defaultLocalization: "en",
    platforms: [.iOS("15.0")],
    products: [
        // Products define the executables and libraries a package produces, and make them visible to other packages.
        .library(
            name: "LoopKit",
            targets: ["LoopKit"]),
        .library(
            name: "LoopKitUI",
            targets: ["LoopKitUI"]),
    ],
    dependencies: [
        .package(
            url: "https://github.com/ivanschuetz/SwiftCharts",
            branch: "master"
        )
        // Dependencies declare other packages that this package depends on.
        // .package(url: /* package url */, from: "1.0.0"),
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages this package depends on.
        .target(
            name: "LoopKit",
            dependencies: [],
            path: "LoopKit"),
        .testTarget(
            name: "LoopKitTests",
            dependencies: ["LoopKit"],
            path: "LoopKitTests",
            resources: [
                .copy("Fixtures")
            ]),
        .target(
            name: "LoopKitUI",
            dependencies: ["LoopKit", "SwiftCharts"],
            path: "LoopKitUI"),
        .target(
            name: "LoopTestingKit",
            dependencies: ["LoopKit"],
            path: "LoopTestingKit"),
        .target(
            name: "MockKit",
            dependencies: ["LoopKit", "LoopKitUI", "LoopTestingKit"],
            path: "MockKit"),
        .target(
            name: "MockKitUI",
            dependencies: ["MockKit", "LoopKit", "LoopKitUI"],
            path: "MockKitUI"),
    ]
)
