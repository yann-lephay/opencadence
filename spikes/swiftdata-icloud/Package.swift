// swift-tools-version: 6.1

import PackageDescription

let package = Package(
    name: "CadencePersistenceSpike",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "CadencePersistenceSpike",
            targets: ["CadencePersistenceSpike"]
        )
    ],
    targets: [
        .target(name: "CadencePersistenceSpike"),
        .testTarget(
            name: "CadencePersistenceSpikeTests",
            dependencies: ["CadencePersistenceSpike"]
        )
    ]
)
