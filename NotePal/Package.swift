// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "NotePal",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "NotePal", targets: ["NotePal"])
    ],
    targets: [
        .executableTarget(
            name: "NotePal",
            path: "Sources/NotePal",
            resources: [
                .process("Resources")
            ]
        )
    ]
)
