import Foundation
import BlindCore

// An explicit offline imported *model*, not an ARFrame/Observation, tracking
// report, sensor calibration, physical localization capture or movement lease.
private struct GameBody: Decodable {
    let radius, height, margin: Double
    var envelope: BodyEnvelope { .init(radius: radius, height: height, margin: margin) }
}
private struct Leg: Decodable { let from, to: Point3 }
private struct Request: Decodable {
    let mode, command: String
    let surface: NavigationSurface?
    let body: GameBody?
    let legs: [Leg]?
}
private enum Failure: Error { case invalidMode, invalidLifecycle, invalidBody, invalidLegs, extraFields }

@main private enum SurfaceGameWorker {
    static func main() throws {
        guard CommandLine.arguments.count == 1 else { throw Failure.invalidLifecycle }
        var surface: NavigationSurface?
        var body: BodyEnvelope?
        var physicalOwner: SpatialRouteOwner?
        let allowed: Set<String> = ["mode", "command", "surface", "body", "legs"]
        while let line = readLine() {
            guard line.utf8.count <= 32 * 1024 * 1024,
                  let bytes = line.data(using: .utf8),
                  let object = try JSONSerialization.jsonObject(with: bytes) as? [String: Any],
                  Set(object.keys).isSubset(of: allowed) else { throw Failure.extraFields }
            let request = try JSONDecoder().decode(Request.self, from: bytes)
            guard request.mode == "offline-known-phone-map-game-v1" else { throw Failure.invalidMode }
            var output: [String: Any] = ["mode": request.mode, "physicalAuthority": false,
                "meaning": "stored simulation-model fit only; not current measured clearance"]
            switch request.command {
            case "initialize":
                guard surface == nil, let input = request.surface, let profile = request.body,
                      request.legs == nil else { throw Failure.invalidLifecycle }
                try input.validate()
                guard profile.envelope.valid else { throw Failure.invalidBody }
                surface = input; body = profile.envelope
                physicalOwner = try SpatialRouteOwner(body: profile.envelope,
                    limits: .init(maximumPositionUncertainty: 0.1, maximumHeadingUncertainty: 0.1))
                output["status"] = "importedOfflineModel"
                output["cells"] = input.cells.count
            case "validateLegs":
                guard let surface, let body, request.surface == nil, request.body == nil,
                      let legs = request.legs, legs.count <= 4096 else { throw Failure.invalidLegs }
                output["permits"] = legs.map { surface.permitsLeg(from: $0.from, to: $0.to, body: body) }
                output["status"] = "storedLegsAssessed"
            default: throw Failure.invalidLifecycle
            }
            output["physicalOwnerHasLocalizationEvidence"] = physicalOwner?.hasLocalizationEvidence ?? false
            output["physicalOwnerHasCurrentPose"] = physicalOwner?.currentPose(now: 0) != nil
            let encoded = try JSONSerialization.data(withJSONObject: output, options: [.sortedKeys])
            try FileHandle.standardOutput.write(contentsOf: encoded + Data([10]))
        }
    }
}
