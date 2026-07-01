// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "TUIkit",
    // Minimum deployment targets for Apple platforms
    // Linux is automatically supported (no platform specification needed)
    platforms: [
        .macOS(.v14)
    ],
    products: [
        // ── Low-level (no deps) ─────────────────────────────────────────────────────────────────────────
        .library(name: "TUIkitCore", targets: ["TUIkitCore"]),
        .library(name: "TUIkitStyling", targets: ["TUIkitStyling"]),

        // ── Mid-level ───────────────────────────────────────────────────────────────────────────────────
        .library(name: "TUIkitView", targets: ["TUIkitView"]),
        .library(name: "TUIkitImage", targets: ["TUIkitImage"]),

        // ── High-level (aggregates all) ─────────────────────────────────────────────────────────────────
        .library(name: "TUIkit", targets: ["TUIkit"]),
        .library(name: "TUIkitPreview", targets: ["TUIkitPreview"]),

        // ── App ─────────────────────────────────────────────────────────────────────────────────────────
        .executable(name: "TUIkitExample", targets: ["TUIkitExample"]),
        .executable(name: "tuikit-preview", targets: ["tuikit-preview"]),
        .plugin(name: "TUIkitPreviewPlugin", targets: ["TUIkitPreviewPlugin"]),
    ],
    dependencies: [
        .package(url: "https://github.com/swiftlang/swift-docc-plugin", from: "1.4.3"),
    ],
    targets: [
        // ── Low-level (no deps) ─────────────────────────────────────────────────────────────────────────
        .target(name: "CSTBImage", publicHeadersPath: "include"),
        .target(name: "TUIkitCore"),
        .target(name: "TUIkitStyling"),

        // ── Mid-level ───────────────────────────────────────────────────────────────────────────────────
        .target(name: "TUIkitView", dependencies: ["TUIkitCore"]),
        .target(name: "TUIkitImage", dependencies: ["CSTBImage", "TUIkitStyling"]),

        // ── High-level (aggregates all) ─────────────────────────────────────────────────────────────────
        .target(
            name: "TUIkit",
            dependencies: ["TUIkitCore", "TUIkitStyling", "TUIkitImage", "TUIkitView"],
            resources: [.copy("Localization/translations"), .copy("VERSION")]
        ),
        .target(name: "TUIkitPreview", dependencies: ["TUIkit"]),

        // ── App & Tests ─────────────────────────────────────────────────────────────────────────────────
        .executableTarget(name: "tuikit-preview", path: "Sources/TUIkitPreviewCLI"),
        .plugin(
            name: "TUIkitPreviewPlugin",
            capability: .command(
                intent: .custom(verb: "tuikit-preview", description: "Run TUIkit live previews"),
                permissions: [
                    .writeToPackageDirectory(reason: "The live preview runner invokes SwiftPM builds for the selected preview package.")
                ]
            ),
            dependencies: [.target(name: "tuikit-preview")]
        ),
        .executableTarget(
            name: "TUIkitExample",
            dependencies: ["TUIkit"],
            resources: [.copy("Resources")]
        ),
        .testTarget(name: "TUIkitTests", dependencies: ["TUIkit"]),
        .testTarget(name: "TUIkitPreviewTests", dependencies: ["TUIkitPreview"]),
    ]
)
