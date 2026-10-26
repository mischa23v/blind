import Foundation
import NativeDepthPolicySupport

// Audit-only byte reader and counters. No pose, tracking, intrinsics, body,
// calibration, map, goal, detector or planner input/operation exists here.
private struct Input: Decodable { let frames: [Frame] }
private struct Frame: Decodable {
    let id, width, height: Int
    let depthPath, confidencePath: String
}
private struct Counts: Codable {
    var attempted = 0, admitted = 0
    var rejectedConfidence0 = 0, rejectedConfidence1 = 0, rejectedOtherConfidence = 0
    var rejectedNonfiniteDepth = 0, rejectedDepthBelowRange = 0, rejectedDepthAboveRange = 0
    var admittedConversionExact = 0
    var rejected: Int { rejectedConfidence0 + rejectedConfidence1 + rejectedOtherConfidence + rejectedNonfiniteDepth + rejectedDepthBelowRange + rejectedDepthAboveRange }
}
private struct Result: Encodable {
    let frameID, width, height, fullRasterPixels, unsampledPixels: Int
    let counts: Counts
}
private struct Output: Encodable {
    let scope = "production scalar depth/confidence admission only; not obstacle detection, avoidance, clearance or navigation"
    let tracking = "unknown and unused"
    let intrinsicsUsed = false, cameraOrWorldProjectionUsed = false, physicalAuthority = false
    let pixelStride: Int
    let results: [Result]
}
private enum Failure: Error { case invalidArguments, invalidManifest, invalidRaster, unexplainedPolicyResult, countMismatch }

@main private enum Audit {
    static func main() throws {
        guard CommandLine.arguments.count == 2 else { throw Failure.invalidArguments }
        let input = try JSONDecoder().decode(Input.self, from: Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[1])))
        guard input.frames.map(\.id) == Array(0..<8), NativeDepthObservationPolicy.pixelStride == 2 else { throw Failure.invalidManifest }
        var results: [Result] = []
        for frame in input.frames {
            guard frame.width == 256, frame.height == 192 else { throw Failure.invalidManifest }
            let depths = try Data(contentsOf: URL(fileURLWithPath: frame.depthPath))
            let confidences = try Data(contentsOf: URL(fileURLWithPath: frame.confidencePath))
            let pixels = frame.width * frame.height
            guard depths.count == pixels * 4, confidences.count == pixels else { throw Failure.invalidRaster }
            var counts = Counts()
            for row in stride(from: 0, to: frame.height, by: NativeDepthObservationPolicy.pixelStride) {
                for column in stride(from: 0, to: frame.width, by: NativeDepthObservationPolicy.pixelStride) {
                    let index = row * frame.width + column, offset = index * 4
                    let bits = UInt32(depths[offset]) | (UInt32(depths[offset + 1]) << 8)
                        | (UInt32(depths[offset + 2]) << 16) | (UInt32(depths[offset + 3]) << 24)
                    let depth = Float(bitPattern: bits), confidence = confidences[index]
                    counts.attempted += 1
                    // This exact shared production return owns the decision.
                    if let accepted = NativeDepthObservationPolicy.acceptedDepth(depth, confidence: confidence) {
                        guard confidence == NativeDepthObservationPolicy.requiredConfidence,
                              NativeDepthObservationPolicy.depthRange.contains(Double(depth)),
                              accepted == Double(depth) else { throw Failure.unexplainedPolicyResult }
                        counts.admitted += 1; counts.admittedConversionExact += 1
                    } else if confidence != NativeDepthObservationPolicy.requiredConfidence {
                        if confidence == 0 { counts.rejectedConfidence0 += 1 }
                        else if confidence == 1 { counts.rejectedConfidence1 += 1 }
                        else { counts.rejectedOtherConfidence += 1 }
                    } else if !depth.isFinite { counts.rejectedNonfiniteDepth += 1 }
                    else if Double(depth) < NativeDepthObservationPolicy.depthRange.lowerBound { counts.rejectedDepthBelowRange += 1 }
                    else if Double(depth) > NativeDepthObservationPolicy.depthRange.upperBound { counts.rejectedDepthAboveRange += 1 }
                    else { throw Failure.unexplainedPolicyResult }
                }
            }
            guard counts.attempted == 12288, counts.admitted + counts.rejected == counts.attempted,
                  counts.admitted == counts.admittedConversionExact else { throw Failure.countMismatch }
            results.append(Result(frameID: frame.id, width: frame.width, height: frame.height,
                                  fullRasterPixels: pixels, unsampledPixels: pixels - counts.attempted, counts: counts))
        }
        let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        FileHandle.standardOutput.write(try encoder.encode(Output(pixelStride: NativeDepthObservationPolicy.pixelStride, results: results)))
        FileHandle.standardOutput.write(Data([10]))
    }
}
