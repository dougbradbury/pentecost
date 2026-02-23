// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "SpeechFrameworkBugRepro",
    platforms: [
        .macOS(.v15)  // macOS 26.0 beta
    ],
    targets: [
        .executableTarget(
            name: "MinimalRepro",
            path: ".",
            sources: ["MinimalReproduction.swift"]
        ),
        .executableTarget(
            name: "AggressiveRepro",
            path: ".",
            sources: ["AggressiveReproduction.swift"]
        ),
        .executableTarget(
            name: "UltraAggressiveRepro",
            path: ".",
            sources: ["UltraAggressiveReproduction.swift"]
        )
    ]
)
