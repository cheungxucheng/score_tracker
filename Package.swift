// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "ScoreTrackerCore",
    products: [
        .library(
            name: "ScoreTrackerCore",
            targets: ["ScoreTrackerCore"]
        )
    ],
    targets: [
        .target(
            name: "ScoreTrackerCore",
            path: ".",
            exclude: [
                "ScoreTrackerApp.swift",
                "Tests"
            ],
            sources: ["ScoreTrackerCore.swift"]
        ),
        .testTarget(
            name: "ScoreTrackerCoreTests",
            dependencies: ["ScoreTrackerCore"],
            path: "Tests"
        )
    ]
)
