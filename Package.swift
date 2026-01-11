// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "GitMonitor",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(
            name: "GitMonitor",
            targets: ["GitMonitor"]
        )
    ],
    targets: [
        .executableTarget(
            name: "GitMonitor",
            path: ".",
            exclude: [
                "Package.swift",
                "README.md",
                "run.sh",
                "docs",
                "Tests",
                "Resources/Info.plist",
                "app_icon_source.png",
                "CLAUDE.md",
                "convert_glb_to_dae.py"
            ],
            sources: [
                "Models",
                "ViewModels",
                "Views",
                "Services",
                "GitMonitorApp.swift"
            ],
            resources: [
                .process("Resources/Asset.xcassets"),
                .process("Resources/3DAssets")
            ],
            swiftSettings: [
                .unsafeFlags(["-parse-as-library"])
            ]
        ),
        .testTarget(
            name: "GitMonitorTests",
            dependencies: ["GitMonitor"]
        )
    ]
)
