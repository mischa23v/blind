import Foundation

public enum RoomPreviewError: Error, Equatable {
    case invalidContext, invalidArtifact, invalidRoute, staleCandidate
}

/// Labels are caller-supplied associations, NOT recognized rooms or a transform.
/// Coordinates remain in the source frame, in metres, +Y up, X/Z horizontal.
public struct RoomPreviewContext: Equatable {
    public let placeID: String, floorID: String, roomID: String, frameID: String
    public let poseProvenance: String, supportProvenance: String
    public init(placeID: String, floorID: String, roomID: String, frameID: String,
                poseProvenance: String, supportProvenance: String) throws {
        let values = [placeID, floorID, roomID, frameID, poseProvenance, supportProvenance]
        guard values.allSatisfy({ !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && $0.utf8.count <= 512 }) else {
            throw RoomPreviewError.invalidContext
        }
        self.placeID = placeID; self.floorID = floorID; self.roomID = roomID; self.frameID = frameID
        self.poseProvenance = poseProvenance; self.supportProvenance = supportProvenance
    }
}

public enum RoomPreviewState: String {
    case candidateOnly, withheldUnknownCoverage, withheldIncompleteRoute
}

/// Intentionally NOT IndoorMap / SpatialMapInstallation / a navigation ticket.
/// A route line is not a floor polygon, body clearance, or observed free space.
public struct RoomMeshPreview {
    public let context: RoomPreviewContext
    public let sourceID: String
    public let points: [[Float]], projectedStart: [Float], projectedGoal: [Float]
    public let complete: Bool, nativeStatus: UInt32
    public let unknownCoverage: [String]
    public let sourceDeliveryComplete: Bool
    public let state: RoomPreviewState
    public let physicalAuthority = false
    public let actualWorldCoverageKnown = false
    public let bodyHeadingKnown = false
    public let clearanceVerified = false
    // No navigation surfaces, guessed transforms, or ground-contact exemptions exported.
    /// Candidate geometry only. This initializer cannot grant physical authority.
    public init(context: RoomPreviewContext, sourceID: String, points: [[Float]],
                projectedStart: [Float], projectedGoal: [Float], complete: Bool,
                nativeStatus: UInt32, unknownCoverage: [String], sourceDeliveryComplete: Bool) throws {
        guard !sourceID.isEmpty, sourceID.utf8.count <= 512 else { throw RoomPreviewError.invalidArtifact }
        try self.init(context: context, sourceID: sourceID,
            route: SavedRoute(points: points, projected_start: projectedStart, projected_goal: projectedGoal,
                              complete: complete, status: nativeStatus, error: nil),
            unknownCoverage: unknownCoverage, sourceDeliveryComplete: sourceDeliveryComplete)
    }
    fileprivate init(context: RoomPreviewContext, sourceID: String, route: SavedRoute,
                     unknownCoverage: [String], sourceDeliveryComplete: Bool) throws {
        try route.validate()
        guard unknownCoverage.count <= 256,
              unknownCoverage.allSatisfy({ !$0.isEmpty && $0.utf8.count <= 512 }) else {
            throw RoomPreviewError.invalidArtifact
        }
        self.context = context; self.sourceID = sourceID
        points = route.points; projectedStart = route.projected_start; projectedGoal = route.projected_goal
        complete = route.complete; nativeStatus = route.status
        self.unknownCoverage = unknownCoverage; self.sourceDeliveryComplete = sourceDeliveryComplete
        state = !route.complete ? .withheldIncompleteRoute :
            (!sourceDeliveryComplete || !unknownCoverage.isEmpty ? .withheldUnknownCoverage : .candidateOnly)
    }
}

fileprivate struct SavedRoute: Decodable {
    let points: [[Float]], projected_start: [Float], projected_goal: [Float]
    let complete: Bool, status: UInt32
    let error: String?
    func validate() throws {
        guard error == nil, !points.isEmpty, points.count <= 4096,
              (points + [projected_start, projected_goal]).allSatisfy({ $0.count == 3 && $0.allSatisfy(\.isFinite) }),
              status & (1 << 31) == 0, status & (1 << 30) != 0,
              points.first == projected_start,
              (!complete || points.last == projected_goal) else { throw RoomPreviewError.invalidRoute }
    }
}

/// Decoder for the existing package's archived ROUTE_DIAGNOSTIC.json, not a
/// reimplementation of Recast. The chosen route's coordinates are copied unchanged.
public enum SavedRoomMeshPreview {
    public enum Variant: String { case original = "actualOriginal", replayed = "actualReplayed", excluded = "actualExcluded" }
    private struct Archive: Decodable {
        let schema: Int, physicalAuthority: Bool
        let actualOriginal: [SavedRoute], actualReplayed: [SavedRoute], actualExcluded: [SavedRoute]
    }
    /// sha256 must be the platform SHA-256 implementation, e.g. CryptoKit.
    /// Digest verifies bytes against a separately pinned receipt, not sensor truth.
    public static func load(data: Data, expectedSHA256: String, sha256: (Data) throws -> String,
                            variant: Variant, index: Int, context: RoomPreviewContext) throws -> RoomMeshPreview {
        guard !data.isEmpty, data.count <= 2_000_000, expectedSHA256.count == 64,
              expectedSHA256.utf8.allSatisfy({ (48...57).contains($0) || (97...102).contains($0) }),
              try sha256(data) == expectedSHA256 else { throw RoomPreviewError.invalidArtifact }
        let archive = try JSONDecoder().decode(Archive.self, from: data)
        guard archive.schema == 1, !archive.physicalAuthority else { throw RoomPreviewError.invalidArtifact }
        let routes: [SavedRoute]
        switch variant {
        case .original: routes = archive.actualOriginal
        case .replayed: routes = archive.actualReplayed
        case .excluded: routes = archive.actualExcluded
        }
        guard routes.count <= 100, routes.indices.contains(index) else { throw RoomPreviewError.invalidRoute }
        return try RoomMeshPreview(context: context,
            sourceID: expectedSHA256 + ":" + variant.rawValue + ":" + String(index), route: routes[index],
            unknownCoverage: ["archive-does-not-prove-current-floor-support", "archive-does-not-prove-current-hazards"],
            sourceDeliveryComplete: false)
    }
}


/// Import presentation lease, not a sensor/localization lease. Retiring a view or
/// backgrounding invalidates pending callbacks; reopening cannot revive old work.
public struct RoomPreviewImportLease {
    private var active = false
    private var pending: UUID?
    public init() {}
    public mutating func activate() { active = true }
    public mutating func retire() { active = false; pending = nil }
    public mutating func begin() -> UUID? {
        guard active else { return nil }
        let token = UUID(); pending = token; return token
    }
    public mutating func finish(_ token: UUID) -> Bool {
        guard active, pending == token else { return false }
        pending = nil; return true
    }
}
