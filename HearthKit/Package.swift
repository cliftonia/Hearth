// swift-tools-version: 5.9
import PackageDescription

let settings: [SwiftSetting] = [
    .enableExperimentalFeature("StrictConcurrency"),
    .enableUpcomingFeature("BareSlashRegexLiterals")
]

let package = Package(
    name: "HearthKit",
    defaultLocalization: "en",
    platforms: [.iOS(.v17), .macCatalyst(.v17)],
    products: [
        .library(name: "HearthUI", targets: ["HearthUI"])
    ],
    targets: [
        .target(name: "HearthCore", swiftSettings: settings),
        .target(name: "HearthData", dependencies: ["HearthCore"], swiftSettings: settings),
        .target(name: "HearthDomain", dependencies: ["HearthData", "HearthCore"], swiftSettings: settings),
        .target(
            name: "HearthUI",
            dependencies: ["HearthDomain", "HearthCore"],
            resources: [.process("Resources")],
            swiftSettings: settings
        ),
        .testTarget(name: "HearthDataTests", dependencies: ["HearthData"], swiftSettings: settings),
        .testTarget(name: "HearthDomainTests", dependencies: ["HearthDomain"], swiftSettings: settings),
        .testTarget(name: "HearthUITests", dependencies: ["HearthUI", "HearthDomain"], swiftSettings: settings)
    ]
)
