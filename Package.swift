// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "SpaceWarp",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(
            name: "SpaceWarp",
            targets: ["SpaceWarp"]
        )
    ],
    dependencies: [
        // Database persistence
        .package(url: "https://github.com/groue/GRDB.swift.git", from: "6.24.0"),
        
        // Logging
        .package(url: "https://github.com/apple/swift-log.git", from: "1.5.4"),
        
        // Settings storage with Codable
        .package(url: "https://github.com/sindresorhus/Defaults.git", from: "7.1.1")
    ],
    targets: [
        .executableTarget(
            name: "SpaceWarp",
            dependencies: [
                .product(name: "GRDB", package: "GRDB.swift"),
                .product(name: "Logging", package: "swift-log"),
                .product(name: "Defaults", package: "Defaults")
            ],
            path: "SpaceWarp",
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency")
            ]
        ),
        .testTarget(
            name: "SpaceWarpTests",
            dependencies: ["SpaceWarp"],
            path: "SpaceWarpTests"
        )
    ]
)
