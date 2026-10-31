// swift-tools-version: 5.9
import PackageDescription
// Actual local products; no copied decoder, snapshot, lifecycle or native algorithm.
let package = Package(
    name: "OriginBoundMeshIngress86", platforms: [.iOS(.v17), .macOS(.v13)],
    products: [.library(name: "OriginBoundMeshIngress86", targets: ["OriginBoundMeshIngress86"])],
    dependencies: [.package(path: "../native-mesh-decoder-81"),
        .package(path: "../arkit-mesh-adapter-82"),
        .package(path: "../room-mesh-package-75/BlindRoomMesh")],
    targets: [.target(name: "OriginBoundMeshIngress86", dependencies: [.product(name: "MeshBufferDecoder81", package: "native-mesh-decoder-81"), .product(name: "MeshSnapshot82", package: "arkit-mesh-adapter-82"), .product(name: "BlindRoomMesh", package: "BlindRoomMesh")], path: "Sources")])
