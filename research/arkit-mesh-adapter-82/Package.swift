// swift-tools-version: 5.9
import PackageDescription
// Actual local products; no copied decoder, snapshot, lifecycle or native algorithm.
let package = Package(
    name: "MeshSnapshot82", platforms: [.iOS(.v17), .macOS(.v13)],
    products: [.library(name: "MeshSnapshot82", targets: ["MeshSnapshot82"])],
    dependencies: [.package(path: "../native-mesh-decoder-81")],
    targets: [.target(name: "MeshSnapshot82", dependencies: [.product(name: "MeshBufferDecoder81", package: "native-mesh-decoder-81")], path: "Sources")])
