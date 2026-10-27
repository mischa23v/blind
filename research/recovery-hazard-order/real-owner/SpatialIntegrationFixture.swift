import Foundation
import XCTest
@testable import BlindCore
#if canImport(CryptoKit)
import CryptoKit
#endif

/// Entirely authored synthetic fixture. Coordinates, map, ground support and pose
/// are supplied test inputs, not recovered localization or real sensor observations.
enum SpatialIntegrationFixture {
    static let body = BodyEnvelope(radius: 0.25, height: 1.6, margin: 0.1)
    static let limits = SpatialLocalizationLimits(maximumPositionUncertainty: 0.2, maximumHeadingUncertainty: 0.15)
    static let sha256: SpatialMapSHA256 = { bytes in
        #if canImport(CryptoKit)
        return SHA256.hash(data: bytes).map { String(format: "%02x", $0) }.joined()
        #else
        // Test-only Linux provider: executes the installed OpenSSL implementation,
        // not a handwritten digest and not a production subprocess dependency.
        let process = Process(), input = Pipe(), output = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/openssl")
        process.arguments = ["dgst", "-sha256"]
        process.standardInput = input; process.standardOutput = output
        try process.run()
        input.fileHandleForWriting.write(bytes); try input.fileHandleForWriting.close()
        let result = output.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        guard process.terminationStatus == 0,
              let digest = String(decoding: result, as: UTF8.self).split(whereSeparator: { $0.isWhitespace }).last else {
            throw SpatialInstallationError.invalidDigest
        }
        return String(digest)
        #endif
    }
    static var nodes: [SpatialPlaceNode] {
        [.init(id: "world", kind: .world), .init(id: "site", kind: .place, parentID: "world"),
         .init(id: "building", kind: .building, parentID: "site"),
         .init(id: "floor", kind: .floor, parentID: "building")]
    }
    static func map(revision: String = "r1", surface: Bool = true, clearance: Double = 2.5,
                    blockedCell: (Int, Int)? = nil) -> IndoorMap {
        var cells = Array(repeating: SurfaceCell(floor: 0, clearance: clearance, blocked: false), count: 16 * 12)
        if let (x, z) = blockedCell { cells[z * 16 + x] = .init(floor: nil, clearance: nil, blocked: false) }
        let grid = NavigationSurface(level: "ground", origin: Point3(0, 0, 0), resolution: 0.5,
                                     width: 16, depth: 12, cells: cells)
        var map = IndoorMap(name: "Synthetic loaded-map fixture", nodes: [
            .init(id: "start", name: "Start", level: "ground", position: Point3(1, 0, 3)),
            .init(id: "middle", name: "Middle", level: "ground", position: Point3(3, 0, 3)),
            .init(id: "end", name: "End", level: "ground", position: Point3(6, 0, 3))],
            edges: [.init(from: "start", to: "middle", distance: 2), .init(from: "middle", to: "end", distance: 3)],
            surfaces: surface ? [grid] : nil)
        map.packageID = "fixture-map"; map.packageRevision = revision
        return map
    }
    static func installation(map: IndoorMap = map(), prior: SpatialMapInstallation? = nil) throws -> SpatialMapInstallation {
        let revision = try XCTUnwrap(map.packageRevision)
        let binding = SpatialMapBinding(mapID: "fixture-map", frameID: "fixture-frame-\(revision)", revision: revision)
        let record = SpatialMapRevision(binding: binding, nodeID: "building", metersPerUnit: 1,
                                        floorLevels: ["ground": "floor"])
        var records = prior?.envelope.snapshot.maps ?? []
        if !records.contains(record) { records.append(record) }
        let snapshot = SpatialRegistrySnapshot(nodes: nodes, maps: records, activeBindings: [binding])
        let bytes = try SpatialMapInstallation.canonicalMapBytes(map)
        let artifact = SpatialMapArtifactIdentity(binding: binding, sha256: try sha256(bytes))
        let history = (prior?.envelope.artifactHistory.filter { $0.binding != binding } ?? []) + [artifact]
        return try SpatialMapInstallation(envelope: .init(snapshot: snapshot, binding: binding,
                                                         mapBytes: bytes, artifactHistory: history,
                                                         restrictions: prior?.envelope.restrictions ?? []), sha256: sha256)
    }
    static func owner(installation: SpatialMapInstallation? = nil) throws -> SpatialRouteOwner {
        var owner = try SpatialRouteOwner(body: body, limits: limits)
        try owner.install(try installation ?? self.installation(), persist: { _ in })
        return owner
    }
    static func capture(owner: SpatialRouteOwner, time: Double = 10, x: Double = 1, z: Double = 3,
                        source: SpatialLocalizationCapture.Source = .alignedMapPose,
                        heading: SpatialLocalizationCapture.HeadingSource = .bodyAligned,
                        floor: String = "floor", bodyYaw: Double = -.pi / 2,
                        headingUncertainty: Double = 0.1) throws -> SpatialLocalizationCapture {
        .init(sessionID: owner.sessionID, binding: try XCTUnwrap(owner.installation).binding,
              floorID: floor, position: Point3(x, 1.3, z), bodyYaw: bodyYaw,
              source: source, headingSource: heading, trackingNormal: true,
              positionUncertainty: 0.1, headingUncertainty: headingUncertainty, capturedAt: time)
    }
    static func support(_ capture: SpatialLocalizationCapture, height: Double = 0) -> SpatialFloorSupport {
        .init(binding: capture.binding, floorID: capture.floorID, sessionID: capture.sessionID,
              captureID: capture.id, height: height, capturedAt: capture.capturedAt)
    }
    static func prepared(map: IndoorMap = map(), x: Double = 1, z: Double = 3) throws -> (SpatialRouteOwner, SpatialFloorSupport) {
        var owner = try self.owner(installation: installation(map: map))
        let goal = UUID(); owner.setGoal(revision: goal)
        try owner.plan(from: "start", to: "end", goal: goal)
        let observation = try capture(owner: owner, x: x, z: z)
        try owner.accept(observation, now: 10)
        return (owner, support(observation))
    }
}
