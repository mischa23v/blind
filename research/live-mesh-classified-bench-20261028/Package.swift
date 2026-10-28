// swift-tools-version: 5.9
import PackageDescription

// Staged diagnostic package only. No app/product/workflow membership is changed.
let package = Package(
    name: "LiveMeshClassifiedBench",
    platforms: [.iOS(.v17), .macOS(.v13)],
    products: [.library(name: "LiveMeshClassifiedBench", targets: ["LiveMeshClassifiedBench"])],
    dependencies: [
        .package(path: "../mesh-candidate-ingress-83"),
        .package(path: "../arkit-mesh-adapter-82"),
        .package(path: "../native-mesh-decoder-81"),
        .package(path: "../room-mesh-package-75/BlindRoomMesh")
    ],
    targets: [
        .target(name: "LiveMeshClassifiedBench", dependencies: [
            .product(name: "MeshCandidateIngress83", package: "mesh-candidate-ingress-83"),
            .product(name: "MeshSnapshot82", package: "arkit-mesh-adapter-82"),
            .product(name: "MeshBufferDecoder81", package: "native-mesh-decoder-81"),
            .product(name: "BlindRoomMesh", package: "BlindRoomMesh")
        ], path: "Sources"),
        .testTarget(name: "LiveMeshClassifiedBenchTests", dependencies: [
            "LiveMeshClassifiedBench",
            .product(name: "MeshSnapshot82", package: "arkit-mesh-adapter-82"),
            .product(name: "MeshCandidateIngress83", package: "mesh-candidate-ingress-83"),
            .product(name: "BlindRoomMesh", package: "BlindRoomMesh")
        ], path: "Tests")
    ])
