// swift-tools-version: 6.1
import PackageDescription

let package = Package(
    name: "RealTimeTranslatorApp",
    platforms: [
        .macOS(.v15)
    ],
    products: [
        .executable(name: "MultilingualRecognizer", targets: ["MultilingualRecognizer"])
    ],
    targets: [
        .executableTarget(
            name: "MultilingualRecognizer"
        ),
        .testTarget(
            name: "MultilingualRecognizerTests",
            dependencies: ["MultilingualRecognizer"]
        )
    ]
)