import Foundation
import BlindCore

// Offline real-mesh import audit. Unknown free space must not authorize a route.
guard CommandLine.arguments.count == 2 else {
    fatalError("Usage: RealSceneEvaluation artifacts/real-scene/surface.json")
}
let surface = try JSONDecoder().decode(NavigationSurface.self,
    from: Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[1])))
try surface.validate()
let floorCount = surface.cells.filter { $0.floor != nil }.count
let blockedCount = surface.cells.filter(\.blocked).count
precondition(floorCount > 0 && blockedCount > 0, "Fixture must contain real floor and obstacles")
precondition(surface.cells.allSatisfy { $0.clearance == nil }, "Mesh absence is not observed free space")
var checked = 0
for (index, cell) in surface.cells.enumerated() where cell.floor != nil {
    let point = Point3(surface.origin.x + (Double(index % surface.width) + 0.5) * surface.resolution,
                       cell.floor!, surface.origin.z + (Double(index / surface.width) + 0.5) * surface.resolution)
    precondition(!surface.permitsLeg(from: point, to: point), "Unknown body clearance must withhold guidance")
    checked += 1
}
let output: [String: Any] = ["passed": true, "observedFloorCells": floorCount,
    "obstacleCells": blockedCount, "unknownClearanceChecks": checked,
    "realGeometry": true, "liveSensorTest": false,
    "result": "Real reconstructed surface accepted; unsupported route clearance refused."]
let data = try JSONSerialization.data(withJSONObject: output, options: [.prettyPrinted, .sortedKeys])
print(String(decoding: data, as: UTF8.self))
