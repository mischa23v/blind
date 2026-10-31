// swift-tools-version: 5.9
import PackageDescription
let package = Package(name: "BlindRoomPreview", platforms: [.iOS(.v17), .macOS(.v13)],
    products: [.library(name: "BlindRoomPreview", targets: ["BlindRoomPreview"])],
    dependencies: [.package(path: "../room-mesh-package-75/BlindRoomMesh"), .package(path: "../../BlindCore")],
    targets: [
        .target(name: "BlindRoomPreview", dependencies: [.product(name: "BlindCore", package: "BlindCore"), .product(name: "BlindRoomMesh", package: "BlindRoomMesh")]),
        .testTarget(name: "BlindRoomPreviewTests", dependencies: ["BlindRoomPreview", .product(name: "BlindCore", package: "BlindCore")], resources: [.copy("Fixtures")])
    ])
