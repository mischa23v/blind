// swift-tools-version: 5.9
import PackageDescription
let package = Package(name: "BlindRoomMesh", platforms: [.iOS(.v17), .macOS(.v13)],
 products: [.library(name: "BlindRoomMesh", targets: ["BlindRoomMesh"])],
 targets: [
  .target(name: "CDetour", path: "Sources/CDetour",
   sources: ["upstream/Recast/Source", "upstream/Detour/Source", "upstream/DetourCrowd/Source", "clearance_adapter.cpp"],
   publicHeadersPath: "include", cxxSettings: [.headerSearchPath("upstream/Recast/Include"), .headerSearchPath("upstream/Detour/Include"), .headerSearchPath("upstream/DetourCrowd/Include"), .unsafeFlags(["-ffp-contract=off", "-fno-rtti", "-fno-exceptions"]) ]),
  .target(name: "CEarcut", path: "Sources/CEarcut", exclude: ["LICENSE"],
   sources: ["earcut_adapter.cpp"], publicHeadersPath: "include",
   cxxSettings: [.unsafeFlags(["-ffp-contract=off"])]),
  .target(name: "BlindRoomMesh", dependencies: ["CDetour", "CEarcut"])
 ], cxxLanguageStandard: .cxx14)
