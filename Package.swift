// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Brighter",
    platforms: [.macOS(.v13)],
    products: [
        .executable(
            name: "Brighter",
            targets: ["Brighter"]
        ),
    ],
    targets: [
        .executableTarget(
            name: "Brighter",
            dependencies: [],
            path: "Brighter",
            resources: [
                .copy("Resources")
            ]
        ),
        .testTarget(
            name: "BrighterTests",
            dependencies: ["Brighter"],
            path: "BrighterTests"
        ),
    ]
)
