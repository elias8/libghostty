// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "flterm",
    platforms: [.macOS("12.0")],
    products: [.library(name: "flterm", targets: ["flterm"])],
    dependencies: [
        .package(name: "FlutterFramework", path: "../FlutterFramework")
    ],
    targets: [
        .target(
            name: "flterm",
            dependencies: [
                .product(name: "FlutterFramework", package: "FlutterFramework")
            ]
        )
    ]
)
