// swift-tools-version: 6.1
import PackageDescription

let package = Package(
    name: "RealTimeTranslatorApp",
    platforms: [
        .macOS(.v15)
    ],
    products: [
        .executable(name: "PentecostGUI", targets: ["PentecostGUI"])
    ],
    targets: [
        .target(
            name: "PentecostCore",
            path: "Sources/MultilingualRecognizer",
            exclude: ["main.swift"]
        ),
        .executableTarget(
            name: "PentecostGUI",
            dependencies: ["PentecostCore"]
        ),
        .testTarget(
            name: "PentecostCoreTests",
            dependencies: ["PentecostCore"]
        )
    ]
)
