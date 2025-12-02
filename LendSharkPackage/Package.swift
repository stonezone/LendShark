// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "LendSharkFeature",
    platforms: [
        .iOS(.v26),
        .macOS(.v26)
    ],
    products: [
        .library(
            name: "LendSharkFeature",
            targets: ["LendSharkFeature"]
        ),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "LendSharkFeature",
            dependencies: [],
            resources: [
                .process("Core/Infrastructure/LendShark.xcdatamodeld")
            ]
        ),
        .testTarget(
            name: "LendSharkFeatureTests",
            dependencies: ["LendSharkFeature"]
        ),
    ]
)
