// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Tessera",
    platforms: [
        .iOS(.v16)
    ],
    products: [
        .library(name: "Tessera", targets: ["Tessera"]),
    ],
    targets: [
        .target(
            name: "Tessera",
            path: "App/Sources",
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "TesseraTests",
            dependencies: ["Tessera"],
            path: "Tests"
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/onevcat/Kingfisher.git", from: "7.10.0"),
        .package(url: "https://github.com/SnapKit/SnapKit.git", from: "5.6.0"),
    ]
)
