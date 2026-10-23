// Compile alongside Geometry.swift and GroundGeometryEvidence.swift, naming this
// source main.swift. See research/GROUND_GEOMETRY_EVIDENCE.md. No external deps.
import Foundation

struct GroundReplayCase: Decodable {
    let id, group, expected: String
    let camera, forward: Point3
    let floor: Double
    let points: [[Double]]
    let assumptions: String
}
struct GroundReplayOutput: Encodable {
    let id, group, historicalExpected, assumptions: String
    let evidence: GroundGeometryEvidence
}
guard CommandLine.arguments.count == 2 else {
    fatalError("Usage: GroundGeometryReplay replay-input.json")
}
let cases = try JSONDecoder().decode([GroundReplayCase].self,
    from: Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[1])))
let output = cases.map { item -> GroundReplayOutput in
    let samples = item.points.compactMap { p -> DepthSample? in
        guard p.count == 3, p.allSatisfy(\.isFinite) else { return nil }
        return DepthSample(Point3(p[0], p[1], p[2]))
    }
    let frame = Observation(timestamp: 1.5, camera: item.camera, forward: item.forward, samples: samples)
    let evidence = GroundGeometryAnalyzer.analyze(frame, now: 1.5, frameID: item.id,
        source: .replay, referenceFloor: item.floor)
    return GroundReplayOutput(id: item.id, group: item.group, historicalExpected: item.expected,
        assumptions: "Replay source may be synthetic, reconstructed virtual rays, or RGB-D; consult group and original provenance. Floor/gravity/confidence inherited from historical input, NOT independently verified. " + item.assumptions,
        evidence: evidence)
}
let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
print(String(decoding: try encoder.encode(output), as: UTF8.self))
