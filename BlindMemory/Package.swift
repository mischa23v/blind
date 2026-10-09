// swift-tools-version: 6.1
import PackageDescription

let package = Package(
    name: "BlindMemory",
    platforms: [.iOS(.v17), .macOS(.v13)],
    products: [.library(name: "BlindMemory", targets: ["BlindMemory"])],
    dependencies: [.package(url: "https://github.com/groue/GRDB.swift.git", exact: "7.11.1")],
    targets: [
        .target(name: "BlindMemory", dependencies: [.product(name: "GRDB", package: "GRDB.swift")], resources: [.process("SQL"), .copy("LICENSE")]),
        .testTarget(name: "BlindMemoryTests", dependencies: ["BlindMemory"])
    ]
)
