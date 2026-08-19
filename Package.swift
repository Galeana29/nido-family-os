// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "NidoCore",
    platforms: [.iOS(.v26), .macOS(.v15)],
    products: [
        .library(name: "NidoDomain", targets: ["NidoDomain"]),
        .library(name: "NidoRoutineEngine", targets: ["NidoRoutineEngine"]),
        .library(name: "NidoPersistence", targets: ["NidoPersistence"]),
        .library(name: "NidoScenario", targets: ["NidoScenario"]),
        .library(name: "NidoTodayFeature", targets: ["NidoTodayFeature"]),
        .executable(name: "NidoScenarioRunner", targets: ["NidoScenarioRunner"]),
        .executable(name: "NidoToday", targets: ["NidoToday"]),
        .executable(name: "NidoWebBridge", targets: ["NidoWebBridge"]),
    ],
    targets: [
        .target(name: "NidoDomain"),
        .target(name: "NidoRoutineEngine", dependencies: ["NidoDomain"]),
        .target(name: "NidoPersistence", dependencies: ["NidoDomain"]),
        .target(name: "NidoScenario", dependencies: ["NidoDomain", "NidoRoutineEngine"]),
        .target(name: "NidoTodayFeature", dependencies: ["NidoDomain", "NidoRoutineEngine"]),
        .executableTarget(name: "NidoScenarioRunner", dependencies: ["NidoScenario"]),
        .executableTarget(name: "NidoToday", dependencies: ["NidoTodayFeature", "NidoScenario", "NidoPersistence"]),
        .executableTarget(name: "NidoWebBridge", dependencies: ["NidoTodayFeature", "NidoScenario", "NidoPersistence"]),
        .testTarget(name: "NidoRoutineEngineTests", dependencies: ["NidoDomain", "NidoRoutineEngine", "NidoScenario"]),
        .testTarget(name: "NidoPersistenceTests", dependencies: ["NidoDomain", "NidoPersistence"]),
        .testTarget(name: "NidoTodayFeatureTests", dependencies: ["NidoDomain", "NidoRoutineEngine", "NidoPersistence", "NidoTodayFeature"]),
    ]
)
