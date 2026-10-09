// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Shakespeare",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "Shakespeare", targets: ["Shakespeare"])
    ],
    targets: [
        // Pure logic: classification, aggregation, persistence. No UI, no networking.
        .target(name: "ShakespeareCore"),
        .executableTarget(name: "Shakespeare", dependencies: ["ShakespeareCore"]),
        .testTarget(name: "ShakespeareCoreTests", dependencies: ["ShakespeareCore"]),
    ]
)
