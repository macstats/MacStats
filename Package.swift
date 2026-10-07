// swift-tools-version: 5.8
import Foundation
import PackageDescription

// The bridging header is passed as an absolute path: the Swift Build engine
// runs the C dependency scanner with a working directory that is not the
// package root, so a relative path makes `swift build` fail to find it.
let bridgingHeader = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent()
    .appendingPathComponent("Sources/MacStats/BridgingHeader.h")
    .path

let package = Package(
    name: "MacStats",
    platforms: [
        .macOS(.v13)
    ],
    targets: [
        .executableTarget(
            name: "MacStats",
            path: "Sources/MacStats",
            swiftSettings: [
                // libproc (proc_pidinfo, PROC_PIDTASKINFO) only reaches Swift
                // through the bridging header, so `swift build` needs it too —
                // not just Scripts/build.sh.
                .unsafeFlags(["-import-objc-header", bridgingHeader])
            ],
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("SwiftUI"),
                .linkedFramework("IOKit"),
                .linkedFramework("ServiceManagement"),
                .linkedFramework("CoreWLAN"),
                .linkedFramework("CoreLocation"),
                .linkedFramework("UserNotifications"),
            ]
        ),
        // Regression cover for the pure logic the app renders. The sources are
        // symlinked in from Sources/MacStats rather than copied, so the tests
        // always exercise the exact files the executable compiles and
        // Scripts/build.sh keeps compiling them as one module.
        .target(
            name: "MacStatsCore",
            path: "Sources/MacStatsCore"
        ),
        // Swift Testing rather than XCTest: XCTest ships with Xcode only and
        // this project is built with a Command Line Tools–only toolchain, so
        // `swift test --disable-xctest` is the invocation that works here.
        .testTarget(
            name: "MacStatsTests",
            dependencies: ["MacStatsCore"],
            path: "Tests/MacStatsTests"
        ),
    ]
)
