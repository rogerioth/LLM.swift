// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "LLM",
    platforms: [
        .iOS("15.0"),
        .macCatalyst("15.0"),
        .macOS("13.3"),
        .watchOS(.v9),
        .tvOS("16.4"),
        .visionOS("1.0")
    ],
    products: [
        .library(
            name: "LLM",
            targets: ["LLM"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-testing.git", branch: "main"),
        .package(url: "https://github.com/swiftlang/swift-docc-plugin", from: "1.1.0")
    ],
    targets: [
        .binaryTarget(
            name: "llama",
            path: "llama.cpp/llama.xcframework"
        ),
        .target(
            name: "LLM",
            dependencies: ["llama"],
            path: "Sources/LLM"
        ),
        .testTarget(
            name: "LLMTests",
            dependencies: [
                "LLM",
                .product(name: "Testing", package: "swift-testing")
            ],
            path: "Tests/LLMTests"
        )
    ]
)
