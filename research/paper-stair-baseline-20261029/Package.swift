// swift-tools-version: 5.9
import PackageDescription
let package = Package(
    name: "PaperStairReference",
    products: [.library(name: "PaperStairReference", targets: ["PaperStairReference"])],
    targets: [.target(name: "PaperStairReference"),
              .testTarget(name: "PaperStairReferenceTests", dependencies: ["PaperStairReference"])]
)
