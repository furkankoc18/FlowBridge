// swift-tools-version: 6.0

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
    swiftLanguageModes: [.v5]
)
