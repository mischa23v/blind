import Foundation
import BlindCore

struct Replay: Decodable {
    var id: String
    var group: String
    var expected: String
    var camera: Point3
    var forward: Point3
    var floor: Double
    var points: [[Double]]
    var assumptions: String
}
struct Result: Encodable {
    var id: String, group: String, expected: String, actual: String
    var specificMatch: Bool, stopWarning: Bool
    var distance: Double?, coverage: Double
    var sampleCount: Int
    var assumptions: String
}
guard CommandLine.arguments.count == 2 else { fatalError("Usage: SensorReplay input.json") }
let cases = try JSONDecoder().decode([Replay].self, from: Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[1])))
var results: [Result] = []
for item in cases {
    // Known LEVEL-floor calibration fixture supplied by the experiment. It is NOT
    // part of a recorded walk and is deliberately separate from real test points.
    var calibration: [DepthSample] = []
    for ahead in stride(from: 0.3, through: 1.3, by: 0.04) {
        for side in stride(from: -0.3, through: 0.3, by: 0.04) {
            calibration.append(DepthSample(Point3(item.camera.x + ahead * item.forward.x - side * item.forward.z,
                item.floor, item.camera.z + ahead * item.forward.z + side * item.forward.x)))
        }
    }
    var detector = HazardDetector(); detector.beginCalibration()
    for i in 0..<15 {
        _ = detector.process(Observation(timestamp: Double(i)*0.1, camera: item.camera,
            forward: item.forward, samples: calibration))
    }
    guard detector.floorHeight != nil else { fatalError("Invalid calibration fixture: \(item.id)") }
    let samples = item.points.map { p -> DepthSample in
        precondition(p.count == 3 && p.allSatisfy(\.isFinite))
        return DepthSample(Point3(p[0], p[1], p[2]))
    }
    let found = detector.process(Observation(timestamp: 1.5, camera: item.camera, forward: item.forward, samples: samples))
    results.append(Result(id: item.id, group: item.group, expected: item.expected,
        actual: found.hazard.rawValue, specificMatch: found.hazard.rawValue == item.expected,
        stopWarning: found.hazard.requiresImmediateAttention, distance: found.distance,
        coverage: found.coverage, sampleCount: samples.count, assumptions: item.assumptions))
}
let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
print(String(decoding: try encoder.encode(results), as: UTF8.self))
