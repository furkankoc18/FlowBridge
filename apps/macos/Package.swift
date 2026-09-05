// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "FlowBridgeMac",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "FlowBridgeMac", targets: ["FlowBridgeMac"]),
    ],
    targets: [
        .executableTarget(
            name: "FlowBridgeMac",
            path: "Sources/FlowBridgeMac"
        ),
    ],
    swiftLanguageVersions: [.v5]
)
