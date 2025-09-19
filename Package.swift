// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "BLEKit",
    platforms: [
        .iOS(.v13),
        .macOS(.v10_15)
    ],
    products: [
        .library(
            name: "BLEKit",
            targets: ["BLEKit"]
        )
    ],
    targets: [
        .target(
            name: "BLEKit",
            path: "BLEKit",
            sources: [
                "BLEKit.swift",
                "BLEManager.swift",
                "BLELogger.swift",
                "BLEKitExample.swift"
            ]
        ),
        .testTarget(
            name: "BLEKitTests",
            dependencies: ["BLEKit"],
            path: "BLEKitTests"
        )
    ]
)