// swift-tools-version: 6.3

import PackageDescription

let swiftSettings: [SwiftSetting] = [
    .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
    .enableUpcomingFeature("InferIsolatedConformances")
]

let composableArchitecture = Target.Dependency.product(
    name: "ComposableArchitecture",
    package: "swift-composable-architecture"
)
let sqliteData = Target.Dependency.product(name: "SQLiteData", package: "sqlite-data")
let dependencies = Target.Dependency.product(name: "Dependencies", package: "swift-dependencies")
let dependenciesMacros = Target.Dependency.product(name: "DependenciesMacros", package: "swift-dependencies")
let dependenciesTestSupport = Target.Dependency.product(
    name: "DependenciesTestSupport",
    package: "swift-dependencies"
)
let clocks = Target.Dependency.product(name: "Clocks", package: "swift-clocks")
let concurrencyExtras = Target.Dependency.product(name: "ConcurrencyExtras", package: "swift-concurrency-extras")
let snapshotTesting = Target.Dependency.product(name: "SnapshotTesting", package: "swift-snapshot-testing")

let package = Package(
    name: "SpeedTestPackage",
    defaultLocalization: "en",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "ICMP", targets: ["ICMP"]),
        .library(name: "SpeedTestKit", targets: ["SpeedTestKit"]),
        .library(name: "DesignSystem", targets: ["DesignSystem"]),
        .library(name: "HistoryFeature", targets: ["HistoryFeature"]),
        .library(name: "SpeedTestFeature", targets: ["SpeedTestFeature"])
    ],
    dependencies: [
        .package(
            url: "https://github.com/pointfreeco/swift-composable-architecture",
            from: "1.26.2",
            traits: ["ComposableArchitecture2Deprecations"]
        ),
        .package(url: "https://github.com/pointfreeco/swift-dependencies", from: "1.17.1"),
        .package(url: "https://github.com/pointfreeco/sqlite-data", from: "1.12.0"),
        .package(url: "https://github.com/pointfreeco/swift-snapshot-testing", from: "1.19.6"),
        .package(url: "https://github.com/pointfreeco/swift-clocks", from: "1.1.1"),
        .package(url: "https://github.com/pointfreeco/swift-concurrency-extras", from: "1.4.1")
    ],
    targets: [
        .target(
            name: "ICMP",
            swiftSettings: swiftSettings
        ),
        .target(
            name: "SpeedTestKit",
            dependencies: ["ICMP", dependencies, dependenciesMacros],
            swiftSettings: swiftSettings
        ),
        .target(
            name: "DesignSystem",
            resources: [.process("Resources")],
            swiftSettings: swiftSettings
        ),
        .target(
            name: "HistoryFeature",
            dependencies: ["DesignSystem", composableArchitecture, sqliteData],
            resources: [.process("Resources")],
            swiftSettings: swiftSettings
        ),
        .target(
            name: "SpeedTestFeature",
            dependencies: [
                "HistoryFeature",
                "DesignSystem",
                "SpeedTestKit",
                "ICMP",
                composableArchitecture,
                sqliteData
            ],
            resources: [.process("Resources")],
            swiftSettings: swiftSettings
        ),
        .target(
            name: "TestSupport",
            dependencies: [concurrencyExtras],
            path: "Tests/TestSupport",
            swiftSettings: swiftSettings
        ),
        .testTarget(
            name: "ICMPTests",
            dependencies: ["ICMP", "TestSupport", clocks],
            swiftSettings: swiftSettings
        ),
        .testTarget(
            name: "SpeedTestKitTests",
            dependencies: ["SpeedTestKit", "ICMP", "TestSupport", clocks, concurrencyExtras, dependenciesTestSupport],
            resources: [.copy("Fixtures")],
            swiftSettings: swiftSettings
        ),
        .testTarget(
            name: "DesignSystemTests",
            dependencies: ["DesignSystem"],
            swiftSettings: swiftSettings
        ),
        .testTarget(
            name: "HistoryFeatureTests",
            dependencies: ["HistoryFeature", dependenciesTestSupport],
            swiftSettings: swiftSettings
        ),
        .testTarget(
            name: "SpeedTestFeatureTests",
            dependencies: [
                "SpeedTestFeature",
                "SpeedTestKit",
                "ICMP",
                "TestSupport",
                composableArchitecture,
                dependenciesTestSupport,
                snapshotTesting,
                clocks
            ],
            swiftSettings: swiftSettings
        )
    ],
    swiftLanguageModes: [.v6]
)
