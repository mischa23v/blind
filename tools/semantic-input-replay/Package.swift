// swift-tools-version: 5.9
import PackageDescription
let package = Package(name: "CompanionInputReplay", platforms: [.macOS(.v13)],
    dependencies: [.package(path: "../../BlindCore")],
    targets: [.executableTarget(name: "CompanionInputReplay", dependencies: [.product(name: "BlindCore", package: "BlindCore")])])
