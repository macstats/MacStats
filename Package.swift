// swift-tools-version: 5.8
import PackageDescription

let package = Package(
    name: "MacStats",
    platforms: [
        .macOS(.v13)
    ],
    targets: [
        .executableTarget(
            name: "MacStats",
            path: "Sources/MacStats",
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("SwiftUI"),
                .linkedFramework("IOKit"),
            ]
        )
    ]
)
