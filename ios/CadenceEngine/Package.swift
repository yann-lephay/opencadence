// swift-tools-version: 6.1

import PackageDescription

let package = Package(
    name: "CadenceEngine",
    platforms: [.iOS(.v18), .macOS(.v15)],
    products: [
        .library(name: "CadenceEngine", targets: ["CadenceEngine"]),
        .executable(name: "CadenceSimulator", targets: ["CadenceSimulator"]),
    ],
    targets: [
        .target(name: "CadenceEngine"),
        .executableTarget(
            name: "CadenceSimulator",
            dependencies: ["CadenceEngine"]
        ),
        .testTarget(
            name: "CadenceEngineTests",
            dependencies: ["CadenceEngine"]
        ),
    ]
)
