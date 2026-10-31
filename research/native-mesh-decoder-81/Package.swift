// swift-tools-version: 5.9
import PackageDescription
// Actual local products; no copied decoder, snapshot, lifecycle or native algorithm.
let package = Package(
    name: "MeshBufferDecoder81", platforms: [.iOS(.v17), .macOS(.v13)],
    products: [.library(name: "MeshBufferDecoder81", targets: ["MeshBufferDecoder81"])],
    dependencies: [],
    targets: [.target(name: "MeshBufferDecoder81", dependencies: [], path: "Sources")])
