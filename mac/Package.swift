// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Focus",
    platforms: [.macOS(.v14)],
    targets: [
        // Models, storage and the timer: everything that touches the data files,
        // kept apart from the views so it can be exercised on its own.
        .target(name: "FocusKit", path: "Sources/FocusKit"),

        .executableTarget(name: "Focus", dependencies: ["FocusKit"], path: "Sources/Focus"),

        // XCTest ships with Xcode, which this project does not require, so the
        // checks are a plain executable: `swift run focus-check`.
        .executableTarget(name: "focus-check", dependencies: ["FocusKit"], path: "Sources/FocusCheck")
    ]
)
