// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "NidoCore",
    platforms: [.iOS(.v26), .macOS(.v15)],
    products: [
        .library(name: "NidoDomain", targets: ["NidoDomain"]),
        .library(name: "NidoRoutineEngine", targets: ["NidoRoutineEngine"]),
        .library(name: "NidoScenario", targets: ["NidoScenario"]),
        .executable(name: "NidoScenarioRunner", targets: ["NidoScenarioRunner"]),
    ],
    targets: [
        .target(name: "NidoDomain"),
        .target(name: "NidoRoutineEngine", dependencies: ["NidoDomain"]),
        .target(name: "NidoScenario", dependencies: ["NidoDomain", "NidoRoutineEngine"]),
        .executableTarget(name: "NidoScenarioRunner", dependencies: ["NidoScenario"]),
        .testTarget(name: "NidoRoutineEngineTests", dependencies: ["NidoDomain", "NidoRoutineEngine", "NidoScenario"]),
    ]
)
