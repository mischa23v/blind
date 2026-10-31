// swift-tools-version: 5.9
import PackageDescription

// Regression harness only. Apply the reviewed83 patch in a complete checkout first.
// No app or existing workflow membership is changed by this proposal.
let package = Package(
    name: "MeshClassificationIngressProposal",
    platforms: [.iOS(.v17), .macOS(.v13)],
    dependencies: [
        .package(path: "../mesh-candidate-ingress-83"),
        .package(path: "../arkit-mesh-adapter-82"),
        .package(path: "../room-mesh-package-75/BlindRoomMesh")
    ],
    targets: [.testTarget(name: "MeshClassificationIngressTests", dependencies: [
        .product(name: "MeshCandidateIngress83", package: "mesh-candidate-ingress-83"),
        .product(name: "MeshSnapshot82", package: "arkit-mesh-adapter-82"),
        .product(name: "BlindRoomMesh", package: "BlindRoomMesh")
    ], path: "Tests")])
