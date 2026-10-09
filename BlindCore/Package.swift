// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "BlindCore",
    platforms: [.iOS(.v17), .macOS(.v13)],
    products: [.library(name: "BlindCore", targets: ["BlindCore"]),
               .executable(name: "MobilitySimulation", targets: ["MobilitySimulation"]),
               .executable(name: "AppleModelEvaluation", targets: ["AppleModelEvaluation"]),
               .executable(name: "ImageModelEvaluation", targets: ["ImageModelEvaluation"]),
               .executable(name: "RealSceneEvaluation", targets: ["RealSceneEvaluation"]),
               .executable(name: "SensorReplay", targets: ["SensorReplay"])],
    targets: [
        // guide-prompt.txt is shared word for word with server/src/scene-policy.mjs.
        .target(name: "BlindCore", resources: [.copy("Resources/guide-prompt.txt")]),
        .executableTarget(name: "MobilitySimulation", dependencies: ["BlindCore"]),
        .executableTarget(name: "AppleModelEvaluation", dependencies: ["BlindCore"]),
        .executableTarget(name: "ImageModelEvaluation", dependencies: ["BlindCore"]),
        .executableTarget(name: "RealSceneEvaluation", dependencies: ["BlindCore"]),
        .executableTarget(name: "SensorReplay", dependencies: ["BlindCore"]),
        .testTarget(name: "BlindCoreTests", dependencies: ["BlindCore"], resources: [.copy("Fixtures")])
    ]
)
