// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "NidoCore",
    platforms: [.iOS(.v26), .macOS(.v15)],
    products: [
        .library(name: "NidoDomain", targets: ["NidoDomain"]),
        .library(name: "NidoRoutineEngine", targets: ["NidoRoutineEngine"]),
    ],
    targets: [
        .target(name: "NidoDomain"),
        .target(name: "NidoRoutineEngine", dependencies: ["NidoDomain"]),
        .testTarget(name: "NidoRoutineEngineTests", dependencies: ["NidoDomain", "NidoRoutineEngine"]),
    ]
)
