// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "meeting-countdown",
    platforms: [
        .macOS(.v13),
    ],
    products: [
        .library(
            name: "MeetingCountdownCore",
            targets: ["MeetingCountdownCore"]
        ),
        .executable(
            name: "meeting-countdown",
            targets: ["meeting-countdown"]
        ),
    ],
    targets: [
        .target(
            name: "MeetingCountdownCore",
            resources: [
                .process("Resources"),
            ]
        ),
        .executableTarget(
            name: "meeting-countdown",
            dependencies: ["MeetingCountdownCore"]
        ),
        .testTarget(
            name: "MeetingCountdownCoreTests",
            dependencies: ["MeetingCountdownCore"]
        ),
    ]
)
